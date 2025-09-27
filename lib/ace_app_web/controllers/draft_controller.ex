defmodule AceAppWeb.DraftController do
  use AceAppWeb, :controller

  alias AceApp.Drafts

  def new(conn, _params) do
    changeset = Drafts.change_draft(%Drafts.Draft{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"draft" => draft_params}) do
    # Add user_id to draft params if user is authenticated
    draft_params_with_user = case conn.assigns[:current_user] do
      %{id: user_id} -> Map.put(draft_params, "user_id", user_id)
      nil -> draft_params
    end
    
    case Drafts.create_draft(draft_params_with_user) do
      {:ok, draft} ->
        conn
        |> put_flash(:info, "Draft created successfully!")
        |> redirect(to: "/drafts/#{draft.id}/setup")

      {:error, changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end
end