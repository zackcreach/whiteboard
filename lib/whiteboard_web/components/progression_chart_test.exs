defmodule WhiteboardWeb.Components.ProgressionChartTest do
  use ExUnit.Case, async: true

  alias WhiteboardWeb.Components.ProgressionChart

  describe "boundaries/3" do
    test "uses the requested daily, weekly, and monthly cadence" do
      first = ~U[2024-02-27 14:30:00Z]
      last = ~U[2024-03-03 18:00:00Z]

      assert [~U[2024-02-27 00:00:00Z], ~U[2024-02-28 00:00:00Z], ~U[2024-02-29 00:00:00Z] | _rest] =
               ProgressionChart.boundaries(first, last, :one_week)

      assert [~U[2024-02-25 00:00:00Z], ~U[2024-03-03 00:00:00Z]] =
               ProgressionChart.boundaries(first, last, :one_month)

      assert [~U[2024-02-01 00:00:00Z], ~U[2024-03-01 00:00:00Z]] =
               ProgressionChart.boundaries(first, last, :three_months)
    end

    test "aligns weeks to Sunday across month and year transitions" do
      assert [~U[2023-12-31 00:00:00Z], ~U[2024-01-07 00:00:00Z]] =
               ProgressionChart.boundaries(~U[2024-01-01 12:00:00Z], ~U[2024-01-08 00:00:00Z], :one_month)
    end

    test "changes all-time cadence at each threshold" do
      first = ~U[2024-01-03 12:00:00Z]

      assert [~U[2024-01-03 00:00:00Z], ~U[2024-01-04 00:00:00Z] | _rest] =
               ProgressionChart.boundaries(first, DateTime.shift(first, week: 2), :all)

      assert [~U[2023-12-31 00:00:00Z], ~U[2024-01-07 00:00:00Z] | _rest] =
               ProgressionChart.boundaries(first, DateTime.shift(first, day: 15), :all)

      assert [~U[2024-01-01 00:00:00Z], ~U[2024-02-01 00:00:00Z] | _rest] =
               ProgressionChart.boundaries(first, DateTime.shift(first, week: 13), :all)

      assert [~U[2024-01-01 00:00:00Z], ~U[2025-01-01 00:00:00Z] | _rest] =
               ProgressionChart.boundaries(first, DateTime.shift(first, day: 731), :all)
    end
  end

  describe "chart_model/3" do
    test "serializes ordered users, decimal values, and workout metadata" do
      series = [
        %{
          user: %{email: "first@example.com"},
          points: [
            %{
              occurred_at: ~U[2024-02-29 12:30:00Z],
              weight: Decimal.new("142.25"),
              workout_id: "workout-1",
              workout_name: "Leap day"
            }
          ]
        },
        %{
          user: %{email: "second@example.com"},
          points: [
            %{
              occurred_at: ~U[2024-03-01 12:30:00Z],
              weight: 150.0,
              workout_id: "workout-2",
              workout_name: "March"
            }
          ]
        }
      ]

      assert %{
               axis_label: "Weight",
               series: [
                 %{
                   color: "--chart-series-1",
                   label: "first@example.com",
                   points: [%{weight: 142.25, workout_id: "workout-1", workout_name: "Leap day"}]
                 },
                 %{color: "--chart-series-2", label: "second@example.com"}
               ]
             } = ProgressionChart.chart_model(series, :one_week, "Weight")
    end

    test "returns nil for empty series and expands a single point range" do
      assert nil == ProgressionChart.chart_model([], :all, "Weight")

      point = %{occurred_at: ~U[2024-01-01 00:00:00Z], weight: 1, workout_id: "id", workout_name: "Workout"}

      assert %{range: [1_703_980_800_000, 1_704_153_600_000]} =
               ProgressionChart.chart_model([%{user: %{email: "user@example.com"}, points: [point]}], :all, "Weight")
    end
  end
end
