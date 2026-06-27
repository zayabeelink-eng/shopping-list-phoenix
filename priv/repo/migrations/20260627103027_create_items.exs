defmodule ShoppingList.Repo.Migrations.CreateItems do
  use Ecto.Migration

  def change do
    create table(:items, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :quantity, :integer, default: 1, null: false
      add :is_completed, :boolean, default: false, null: false
      add :sort_order, :integer, default: 0
      add :deleted_at, :naive_datetime
      timestamps()
    end

    create index(:items, [:is_completed])
    create index(:items, [:sort_order])
    create index(:items, [:deleted_at])
  end
end
