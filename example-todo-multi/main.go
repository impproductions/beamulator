package main

import (
	"database/sql"
	"net/http"
	"strconv"

	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"
	"golang.org/x/crypto/bcrypt"

	_ "github.com/mattn/go-sqlite3"
)

type Todo struct {
	ID        int    `json:"id"`
	Title     string `json:"title"`
	Completed bool   `json:"completed"`
	User      string `json:"user"`
}

type User struct {
	ID       int    `json:"id"`
	Username string `json:"username"`
	Password string `json:"password"`
}

var db *sql.DB

func main() {
	var err error
	// Open with DSN parameters to share cache and set a busy timeout
	db, err = sql.Open("sqlite3", "file:todos.db?cache=shared&_busy_timeout=5000")
	if err != nil {
		panic(err)
	}
	defer db.Close()

	// Allow multiple connections (even though writes are serialized)
	db.SetMaxOpenConns(10)

	// Enable WAL mode for better concurrency
	_, err = db.Exec("PRAGMA journal_mode=WAL;")
	if err != nil {
		panic(err)
	}

	createUsersQuery := `
	CREATE TABLE IF NOT EXISTS users (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		username TEXT UNIQUE NOT NULL,
		password TEXT NOT NULL
	);
	`
	_, err = db.Exec(createUsersQuery)
	if err != nil {
		panic(err)
	}

	createTodosQuery := `
	CREATE TABLE IF NOT EXISTS todos (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		title TEXT NOT NULL,
		completed INTEGER NOT NULL,
		user TEXT NOT NULL,
		FOREIGN KEY(user) REFERENCES users(username)
	);
	`
	_, err = db.Exec(createTodosQuery)
	if err != nil {
		panic(err)
	}

	createUserIndexQuery := `
	CREATE INDEX IF NOT EXISTS user_index ON users (username);
	`
	_, err = db.Exec(createUserIndexQuery)
	if err != nil {
		panic(err)
	}

	createTodoIndexQuery := `
	CREATE INDEX IF NOT EXISTS todo_index ON todos (user);
	`
	_, err = db.Exec(createTodoIndexQuery)
	if err != nil {
		panic(err)
	}

	e := echo.New()
	e.Use(middleware.Logger())
	e.Use(middleware.Recover())

	e.GET("/users", listUsers)
	e.POST("/users", createUser)
	e.GET("/users/me", getUser)
	e.PUT("/users/me", updateUser)
	e.DELETE("/users/me", deleteUser)

	e.GET("/todos", getTodos)
	e.POST("/todos", createTodo)
	e.PUT("/todos/:id", updateTodo)
	e.DELETE("/todos/:id", deleteTodo)

	e.Static("/static", "static")

	e.GET("/", func(c echo.Context) error {
		return c.File("templates/index.html")
	})

	e.Logger.Fatal(e.Start(":8080"))
}

func verifyUser(c echo.Context) (string, error) {
	username := c.Request().Header.Get("X-User")
	password := c.Request().Header.Get("X-Password")
	if username == "" || password == "" {
		return "", echo.NewHTTPError(http.StatusBadRequest, "Missing authentication headers")
	}

	var hashed string
	err := db.QueryRow("SELECT password FROM users WHERE username = ?", username).Scan(&hashed)
	if err != nil {
		return "", echo.NewHTTPError(http.StatusUnauthorized, "Invalid credentials")
	}
	if bcrypt.CompareHashAndPassword([]byte(hashed), []byte(password)) != nil {
		return "", echo.NewHTTPError(http.StatusUnauthorized, "Invalid credentials")
	}
	return username, nil
}

func listUsers(c echo.Context) error {
	rows, err := db.Query("SELECT id, username FROM users")
	if err != nil {
		return echo.NewHTTPError(http.StatusInternalServerError, err.Error())
	}
	defer rows.Close()

	users := []User{}
	for rows.Next() {
		var u User
		if err := rows.Scan(&u.ID, &u.Username); err != nil {
			return echo.NewHTTPError(http.StatusInternalServerError, err.Error())
		}
		users = append(users, u)
	}
	return c.JSON(http.StatusOK, users)
}

func createUser(c echo.Context) error {
	u := new(User)
	if err := c.Bind(u); err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, err.Error())
	}
	if u.Username == "" || u.Password == "" {
		return echo.NewHTTPError(http.StatusBadRequest, "username and password required")
	}
	hashed, err := bcrypt.GenerateFromPassword([]byte(u.Password), bcrypt.DefaultCost)
	if err != nil {
		return echo.NewHTTPError(http.StatusInternalServerError, err.Error())
	}
	_, err = db.Exec("INSERT INTO users (username, password) VALUES (?, ?)", u.Username, string(hashed))
	if err != nil {
		return echo.NewHTTPError(http.StatusInternalServerError, err.Error())
	}
	return c.JSON(http.StatusCreated, echo.Map{"message": "user created", "username": u.Username})
}

func getUser(c echo.Context) error {
	username, err := verifyUser(c)
	if err != nil {
		return err
	}
	var u User
	err = db.QueryRow("SELECT id, username FROM users WHERE username = ?", username).Scan(&u.ID, &u.Username)
	if err != nil {
		return echo.NewHTTPError(http.StatusInternalServerError, err.Error())
	}
	return c.JSON(http.StatusOK, u)
}

func updateUser(c echo.Context) error {
	username, err := verifyUser(c)
	if err != nil {
		return err
	}
	var input struct {
		Password string `json:"password"`
	}
	if err := c.Bind(&input); err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, err.Error())
	}
	if input.Password == "" {
		return echo.NewHTTPError(http.StatusBadRequest, "password required")
	}
	hashed, err := bcrypt.GenerateFromPassword([]byte(input.Password), bcrypt.DefaultCost)
	if err != nil {
		return echo.NewHTTPError(http.StatusInternalServerError, err.Error())
	}
	_, err = db.Exec("UPDATE users SET password = ? WHERE username = ?", string(hashed), username)
	if err != nil {
		return echo.NewHTTPError(http.StatusInternalServerError, err.Error())
	}
	return c.JSON(http.StatusOK, echo.Map{"message": "password updated"})
}

func deleteUser(c echo.Context) error {
	username, err := verifyUser(c)
	if err != nil {
		return err
	}

	_, err = db.Exec("DELETE FROM todos WHERE user = ?", username)
	if err != nil {
		return echo.NewHTTPError(http.StatusInternalServerError, err.Error())
	}
	_, err = db.Exec("DELETE FROM users WHERE username = ?", username)
	if err != nil {
		return echo.NewHTTPError(http.StatusInternalServerError, err.Error())
	}
	return c.NoContent(http.StatusNoContent)
}

func getTodos(c echo.Context) error {
	username, err := verifyUser(c)
	if err != nil {
		return err
	}
	rows, err := db.Query("SELECT id, title, completed, user FROM todos WHERE user = ?", username)
	if err != nil {
		return echo.NewHTTPError(http.StatusInternalServerError, err.Error())
	}
	defer rows.Close()

	todos := []Todo{}
	for rows.Next() {
		var t Todo
		var completed int
		if err := rows.Scan(&t.ID, &t.Title, &completed, &t.User); err != nil {
			return echo.NewHTTPError(http.StatusInternalServerError, err.Error())
		}
		t.Completed = completed != 0
		todos = append(todos, t)
	}
	return c.JSON(http.StatusOK, todos)
}

func createTodo(c echo.Context) error {
	username, err := verifyUser(c)
	if err != nil {
		return err
	}
	var count int
	err = db.QueryRow("SELECT COUNT(*) FROM users WHERE username = ?", username).Scan(&count)
	if err != nil || count == 0 {
		return echo.NewHTTPError(http.StatusUnauthorized, "user does not exist")
	}

	var newTodo Todo
	if err := c.Bind(&newTodo); err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, err.Error())
	}
	newTodo.User = username
	res, err := db.Exec("INSERT INTO todos (title, completed, user) VALUES (?, ?, ?)", newTodo.Title, boolToInt(newTodo.Completed), newTodo.User)
	if err != nil {
		return echo.NewHTTPError(http.StatusInternalServerError, err.Error())
	}
	id, err := res.LastInsertId()
	if err != nil {
		return echo.NewHTTPError(http.StatusInternalServerError, err.Error())
	}
	newTodo.ID = int(id)
	return c.JSON(http.StatusCreated, newTodo)
}

func updateTodo(c echo.Context) error {
	username, err := verifyUser(c)
	if err != nil {
		return err
	}
	idParam := c.Param("id")
	id, err := strconv.Atoi(idParam)
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "invalid id")
	}

	var updateData Todo
	if err := c.Bind(&updateData); err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, err.Error())
	}
	res, err := db.Exec("UPDATE todos SET title = ?, completed = ? WHERE id = ? AND user = ?", updateData.Title, boolToInt(updateData.Completed), id, username)
	if err != nil {
		return echo.NewHTTPError(http.StatusInternalServerError, err.Error())
	}
	affected, err := res.RowsAffected()
	if err != nil {
		return echo.NewHTTPError(http.StatusInternalServerError, err.Error())
	}
	if affected == 0 {
		return echo.NewHTTPError(http.StatusNotFound, "todo not found for user")
	}
	updateData.ID = id
	updateData.User = username
	return c.JSON(http.StatusOK, updateData)
}

func deleteTodo(c echo.Context) error {
	username, err := verifyUser(c)
	if err != nil {
		return err
	}
	idParam := c.Param("id")
	id, err := strconv.Atoi(idParam)
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "invalid id")
	}

	res, err := db.Exec("DELETE FROM todos WHERE id = ? AND user = ?", id, username)
	if err != nil {
		return echo.NewHTTPError(http.StatusInternalServerError, err.Error())
	}
	affected, err := res.RowsAffected()
	if err != nil {
		return echo.NewHTTPError(http.StatusInternalServerError, err.Error())
	}
	if affected == 0 {
		return echo.NewHTTPError(http.StatusNotFound, "todo not found for user")
	}
	return c.NoContent(http.StatusNoContent)
}

func boolToInt(b bool) int {
	if b {
		return 1
	}
	return 0
}
