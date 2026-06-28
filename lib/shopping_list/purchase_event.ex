defmodule ShoppingList.PurchaseEvent do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "purchase_events" do
    field :item_name, :string
    field :quantity, :integer, default: 1
    field :purchased_at, :naive_datetime

    timestamps()
  end

  @doc false
  def changeset(purchase_event, attrs) do
    purchase_event
    |> cast(attrs, [:item_name, :quantity, :purchased_at])
    |> validate_required([:item_name, :quantity, :purchased_at])
    |> validate_number(:quantity, greater_than: 0)
  end
end
