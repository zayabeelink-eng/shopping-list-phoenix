defmodule ShoppingList.Repo.Migrations.CreatePurchaseEvents do
  use Ecto.Migration

  def change do
    create table(:purchase_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :item_name, :string, null: false
      add :quantity, :integer, null: false, default: 1
      add :purchased_at, :naive_datetime, null: false

      timestamps()
    end

    create index(:purchase_events, [:item_name])
    create index(:purchase_events, [:purchased_at])
  end
end
