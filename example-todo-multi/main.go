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
	db, err = sql.Open("sqlite3", "./todos.db")
	if err != nil {
		panic(err)
	}
	defer db.Close()

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

	e := echo.New()
	e.Use(middleware.Logger())
	e.Use(middleware.Recover())

	// usage: curl -X POST -H "X-User: user" -H "X-Password: password" http://localhost:8080/users
	e.POST("/users", createUser)
	// usage curl -H "X-User: user" -H "X-Password: password" http://localhost:8080/users/me
	e.GET("/users/me", getUser)
	// usage curl -X PUT -H "X-User: user" -H "X-Password: password" -d '{"password": "newpassword"}' http://localhost:8080/users/me
	e.PUT("/users/me", updateUser)
	// usage curl -X DELETE -H "X-User: user" -H "X-Password: password" http://localhost:8080/users/me
	e.DELETE("/users/me", deleteUser)

	// usage: curl -X GET -H "X-User: user" -H "X-Password: password" http://localhost:8080/todos
	e.GET("/todos", getTodos)
	// usage: curl -X POST -H "X-User: user" -H "X-Password: password" -d '{"title": "new todo", "completed": false}' http://localhost:8080/todos
	e.POST("/todos", createTodo)
	// usage: curl -X PUT -H "X-User: user" -H "X-Password: password" -d '{"title": "updated todo", "completed": true}' http://localhost:8080/todos/1
	e.PUT("/todos/:id", updateTodo)
	// usage: curl -X DELETE -H "X-User: user" -H "X-Password: password" http://localhost:8080/todos/1
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

func createUser(c echo.Context) error {
	u := new(User)
	if err := c.Bind(u); err != nil {
		return err
	}
	if u.Username == "" || u.Password == "" {
		return c.JSON(http.StatusBadRequest, echo.Map{"error": "username and password required: " + u.Username + " " + u.Password})
	}
	hashed, err := bcrypt.GenerateFromPassword([]byte(u.Password), bcrypt.DefaultCost)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, echo.Map{"error": err.Error()})
	}
	_, err = db.Exec("INSERT INTO users (username, password) VALUES (?, ?)", u.Username, string(hashed))
	if err != nil {
		return c.JSON(http.StatusInternalServerError, echo.Map{"error": err.Error()})
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
		return c.JSON(http.StatusInternalServerError, echo.Map{"error": err.Error()})
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
		return err
	}
	if input.Password == "" {
		return c.JSON(http.StatusBadRequest, echo.Map{"error": "password required"})
	}
	hashed, err := bcrypt.GenerateFromPassword([]byte(input.Password), bcrypt.DefaultCost)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, echo.Map{"error": err.Error()})
	}
	_, err = db.Exec("UPDATE users SET password = ? WHERE username = ?", string(hashed), username)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, echo.Map{"error": err.Error()})
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
		return c.JSON(http.StatusInternalServerError, echo.Map{"error": err.Error()})
	}
	_, err = db.Exec("DELETE FROM users WHERE username = ?", username)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, echo.Map{"error": err.Error()})
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
		return c.JSON(http.StatusInternalServerError, echo.Map{"error": err.Error()})
	}
	defer rows.Close()

	todos := []Todo{}
	for rows.Next() {
		var t Todo
		var completed int
		if err := rows.Scan(&t.ID, &t.Title, &completed, &t.User); err != nil {
			return c.JSON(http.StatusInternalServerError, echo.Map{"error": err.Error()})
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
		return c.JSON(http.StatusUnauthorized, echo.Map{"error": "user does not exist"})
	}

	var newTodo Todo
	if err := c.Bind(&newTodo); err != nil {
		return err
	}
	newTodo.User = username
	res, err := db.Exec("INSERT INTO todos (title, completed, user) VALUES (?, ?, ?)", newTodo.Title, boolToInt(newTodo.Completed), newTodo.User)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, echo.Map{"error": err.Error()})
	}
	id, err := res.LastInsertId()
	if err != nil {
		return c.JSON(http.StatusInternalServerError, echo.Map{"error": err.Error()})
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
		return c.JSON(http.StatusBadRequest, echo.Map{"error": "invalid id"})
	}

	var updateData Todo
	if err := c.Bind(&updateData); err != nil {
		return err
	}
	res, err := db.Exec("UPDATE todos SET title = ?, completed = ? WHERE id = ? AND user = ?", updateData.Title, boolToInt(updateData.Completed), id, username)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, echo.Map{"error": err.Error()})
	}
	affected, err := res.RowsAffected()
	if err != nil {
		return c.JSON(http.StatusInternalServerError, echo.Map{"error": err.Error()})
	}
	if affected == 0 {
		return c.JSON(http.StatusNotFound, echo.Map{"error": "todo not found for user"})
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
		return c.JSON(http.StatusBadRequest, echo.Map{"error": "invalid id"})
	}

	res, err := db.Exec("DELETE FROM todos WHERE id = ? AND user = ?", id, username)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, echo.Map{"error": err.Error()})
	}
	affected, err := res.RowsAffected()
	if err != nil {
		return c.JSON(http.StatusInternalServerError, echo.Map{"error": err.Error()})
	}
	if affected == 0 {
		return c.JSON(http.StatusNotFound, echo.Map{"error": "todo not found for user"})
	}
	return c.NoContent(http.StatusNoContent)
}

func boolToInt(b bool) int {
	if b {
		return 1
	}
	return 0
}
