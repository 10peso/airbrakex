defmodule Airbrakex.Plug do
  @moduledoc """
  You can plug `Airbrakex.Plug` in your web application Plug stack
  to send all exception to `airbrake`

  ```elixir
  defmodule YourApp.Router do
    use Phoenix.Router
    use Airbrakex.Plug

    # ...
  end
  ```
  """

  alias Airbrakex.{ExceptionParser, Notifier}

  defmacro __using__(_env) do
    quote location: :keep do
      @before_compile Airbrakex.Plug
    end
  end

  defmacro __before_compile__(_env) do
    quote location: :keep do
      defoverridable call: 2

      def call(conn, opts) do
        try do
          super(conn, opts)
        rescue
          exception ->
            conn = conn |> Plug.Conn.fetch_cookies |> Plug.Conn.fetch_query_params
            headers = Enum.into(conn.req_headers, %{})

            cxt = %{
              url: "#{conn.scheme}://#{conn.host}:#{conn.port}#{conn.request_path}",
              userIP: (conn.remote_ip |> Tuple.to_list() |> Enum.join(".")),
              userAgent: headers["user-agent"],
              cookies: conn.req_cookies
            }
            env = %{
              headers: headers,
              httpMethod: conn.method
            }

            session = Map.get(conn.private, :plug_session)

            error = ExceptionParser.parse(exception)

            Notifier.notify(error, params: conn.params, session: session, context: cxt, environment: env)

            reraise exception, System.stacktrace()
        end
      end
    end
  end
end
