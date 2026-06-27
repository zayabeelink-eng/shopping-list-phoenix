defmodule ShoppingList.List.Item do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "items" do
    field :is_completed, :boolean, default: false
    field :name, :string
    field :quantity, :integer, default: 1
    field :sort_order, :integer, default: 0
    field :deleted_at, :naive_datetime

    timestamps()
  end

  @type t() :: %__MODULE__{
          id: binary(),
          is_completed: boolean(),
          name: String.t(),
          quantity: integer(),
          sort_order: integer(),
          deleted_at: NaiveDateTime.t() | nil,
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  @doc false
  def changeset(item, attrs) do
    item
    |> cast(attrs, [:name, :quantity, :is_completed, :sort_order, :deleted_at])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 200)
    |> validate_number(:quantity, greater_than: 0)
    |> normalize_name()
  end

  defp normalize_name(changeset) do
    case get_change(changeset, :name) do
      nil ->
        changeset

      name ->
        normalized =
          name
          |> String.trim()
          |> capitalize_first()

        put_change(changeset, :name, normalized)
    end
  end

  defp capitalize_first(<<first::utf8, rest::binary>>),
    do: String.upcase(<<first>>) <> String.downcase(rest)

  defp capitalize_first(""), do: ""
end
