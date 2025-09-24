defmodule AceAppWeb.PageController do
  use AceAppWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
