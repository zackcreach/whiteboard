defmodule WhiteboardWeb.Components.WorkoutDetailsDialog do
  @moduledoc false
  use WhiteboardWeb, :component

  alias WhiteboardWeb.Components.FloatingDialog

  attr :open, :boolean, required: true
  attr :form, :any, required: true
  attr :title, :string, default: "Edit workout"
  attr :position_class, :string, default: "left-0 top-full mt-4"

  def render(%{open: false} = assigns) do
    ~H"""
    """
  end

  def render(assigns) do
    ~H"""
    <FloatingDialog.render
      id="workout-details-dialog"
      title={@title}
      close_event="cancel_workout_details"
      close_id="cancel-workout-details"
      close_label="Cancel workout edit"
      focus_target="#workout_details_date"
      position_class={@position_class}
      width_class="w-fit min-w-60 max-w-[calc(100vw-2rem)]"
      divider={true}
    >
      <.form id="workout-details-form" for={@form} phx-submit="update_workout_details" class="flex flex-col gap-3">
        <.input field={@form[:date]} type="date" placeholder="Date" required />
        <.input field={@form[:name]} placeholder="Title" required />
        <.input field={@form[:notes]} type="textarea" placeholder="Notes" />
        <.button id="save-workout-details" type="submit" class="w-full">Save</.button>
      </.form>
    </FloatingDialog.render>
    """
  end
end
