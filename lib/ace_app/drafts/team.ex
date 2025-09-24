defmodule AceApp.Drafts.Team do
  use Ecto.Schema
  import Ecto.Changeset

  schema "teams" do
    field(:name, :string)
    field(:logo_url, :string)
    field(:captain_token, :string)
    field(:team_member_token, :string)
    field(:pick_order_position, :integer)
    field(:is_ready, :boolean, default: false)
    field(:logo_file_size, :integer)
    field(:logo_content_type, :string)

    belongs_to(:draft, AceApp.Drafts.Draft)
    belongs_to(:logo_upload, AceApp.Files.FileUpload)
    has_many(:picks, AceApp.Drafts.Pick)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(team, attrs) do
    team
    |> cast(attrs, [
      :name,
      :logo_url,
      :captain_token,
      :team_member_token,
      :pick_order_position,
      :draft_id,
      :is_ready,
      :logo_upload_id,
      :logo_file_size,
      :logo_content_type
    ])
    |> validate_required([:name, :pick_order_position, :draft_id])
    |> validate_number(:pick_order_position, greater_than: 0)
    |> maybe_generate_captain_token()
    |> maybe_generate_team_member_token()
    |> validate_required([:captain_token, :team_member_token])
    |> unique_constraint([:draft_id, :name])
    |> unique_constraint([:draft_id, :pick_order_position])
    |> unique_constraint(:captain_token)
    |> unique_constraint(:team_member_token)
    |> foreign_key_constraint(:logo_upload_id)
  end

  defp maybe_generate_captain_token(%Ecto.Changeset{} = changeset) do
    if get_field(changeset, :captain_token) do
      changeset
    else
      put_change(changeset, :captain_token, generate_captain_token())
    end
  end

  defp maybe_generate_team_member_token(%Ecto.Changeset{} = changeset) do
    if get_field(changeset, :team_member_token) do
      changeset
    else
      put_change(changeset, :team_member_token, generate_team_member_token())
    end
  end

  defp generate_captain_token do
    # Generate exactly 32 characters total
    prefix_with_underscore = "cap_"
    suffix_length = 32 - String.length(prefix_with_underscore)

    suffix =
      :crypto.strong_rand_bytes(24)
      |> Base.url_encode64(padding: false)
      |> String.slice(0, suffix_length)

    "#{prefix_with_underscore}#{suffix}"
  end

  defp generate_team_member_token do
    # Generate exactly 32 characters total
    prefix_with_underscore = "mem_"
    suffix_length = 32 - String.length(prefix_with_underscore)

    suffix =
      :crypto.strong_rand_bytes(24)
      |> Base.url_encode64(padding: false)
      |> String.slice(0, suffix_length)

    "#{prefix_with_underscore}#{suffix}"
  end
end
