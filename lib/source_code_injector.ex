defmodule SourceInjector do
  defmacro __using__(_opts) do
    quote do
      @source_code File.read!(__ENV__.file)
      def source_code, do: @source_code
    end
  end
end
