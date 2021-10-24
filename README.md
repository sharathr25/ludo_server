# LudoServer
* **STEP 1:** You need **elixir** for this project
  * If you already have elixir then you can skip this step
  * So go here https://elixir-lang.org/install.html and install elixir which is compatible for your OS
  * Run `elixir -v` to check elixir version, If the version comes up then you have successfully installed elixir
  * Elixir comes with the build tool `mix` which we will use to build and run our application

* **STEP 2:** You need **PostgreSQL** as well
  * If you already have PostgreSQL then you can skip this step
  * So go here https://www.postgresql.org/download/ and install PostgreSQL which is compatible for your OS
  * Run `psql --version` to check PostgreSQL version, If the version comes up then you have successfully installed PostgreSQL

* **STEP 3:** In the project directory run `mix deps.get` to install dependencies

* **STEP 4:** Then create and migrate your database with `mix ecto.setup`

* **STEP 5:** Start Phoenix endpoint with `mix phx.server`

Application will be running at [`localhost:5000`](http://localhost:5000)

## Learn more
  * Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).
  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix
