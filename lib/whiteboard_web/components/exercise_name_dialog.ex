defmodule WhiteboardWeb.Components.ExerciseNameDialog do
  @moduledoc false
  use WhiteboardWeb, :component

  alias WhiteboardWeb.Components.FloatingDialog

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :position_class, :string, default: "right-0 top-full mt-4"

  attr :exercise_names, :list, required: true
  attr :current_exercise_name_id, :string, default: nil
  attr :exercise_id, :string, default: nil
  attr :empty_message, :string, default: "No matching exercises"

  attr :query, :string, default: ""
  attr :query_id, :string, required: true
  attr :query_name, :string, required: true
  attr :query_form_id, :string, default: nil
  attr :filter_event, :string, required: true

  attr :option_event, :string, required: true
  attr :option_id_prefix, :string, required: true
  attr :option_name_role, :string, default: "exercise-name-option-name"
  attr :option_role, :string, required: true

  attr :cancel_event, :string, required: true
  attr :cancel_id, :string, required: true
  attr :cancel_label, :string, required: true

  def render(assigns) do
    ~H"""
    <FloatingDialog.render
      id={@id}
      title={@title}
      close_event={@cancel_event}
      close_id={@cancel_id}
      close_label={@cancel_label}
      position_class={@position_class}
      width_class="w-[300px] max-w-[calc(100vw-2rem)]"
      focus_target={"##{@query_id}"}
    >
      <% matching_exercise_names = filtered_exercise_names(@exercise_names, @query) %>
      <form :if={@query_form_id} id={@query_form_id} class="hidden"></form>
      <div class="mb-4">
        <div class="relative">
          <input
            id={@query_id}
            type="search"
            name={@query_name}
            form={@query_form_id}
            value={@query}
            placeholder="Search exercises"
            autocomplete="off"
            phx-change={@filter_event}
            phx-debounce="150"
            class="block w-full appearance-none rounded-lg border border-zinc-300 bg-white p-2.5 pr-9 text-base leading-6 text-zinc-900 focus:border-zinc-400 focus:ring-0 [&::-webkit-search-cancel-button]:hidden dark:border-stone-600 dark:bg-stone-700 dark:text-stone-100 dark:focus:border-stone-500"
          />
          <.icon_button
            :if={clear_search?(@query)}
            id={"#{@query_id}-clear"}
            label="Clear exercise search"
            icon="hero-x-mark size-4"
            phx-click={@filter_event}
            phx-value-value=""
            class="!absolute right-2 top-1/2 h-6 w-6 -translate-y-1/2 justify-center text-zinc-500 hover:text-zinc-900 dark:text-stone-300 dark:hover:text-stone-100"
            hover_class="after:h-6 after:w-6 after:rounded"
          />
        </div>
      </div>
      <div class="h-56 overflow-y-auto">
        <FloatingDialog.row
          :for={exercise_name <- matching_exercise_names}
          id={"#{@option_id_prefix}-#{exercise_name.id}"}
          label={exercise_name.name}
          click={@option_event}
          role={@option_role}
          label_role={@option_name_role}
          values={%{exercise_id: @exercise_id, exercise_name_id: exercise_name.id}}
          disabled={exercise_name.id == @current_exercise_name_id}
        >
          <span :if={exercise_name.id == @current_exercise_name_id} class="text-xs font-medium text-zinc-500 dark:text-stone-300">Current</span>
        </FloatingDialog.row>
        <p :if={matching_exercise_names == []} class="flex h-full items-center justify-center px-2 text-center text-sm text-zinc-500 dark:text-stone-300">{@empty_message}</p>
      </div>
    </FloatingDialog.render>
    """
  end

  defp filtered_exercise_names(exercise_names, query) do
    query
    |> normalize_query()
    |> then(&filter_exercise_names(exercise_names, &1))
  end

  defp filter_exercise_names(exercise_names, ""), do: exercise_names

  defp filter_exercise_names(exercise_names, query) do
    Enum.filter(exercise_names, fn exercise_name ->
      exercise_name
      |> exercise_name_search_values()
      |> Enum.any?(&String.contains?(&1, query))
    end)
  end

  defp exercise_name_search_values(%{name: name, exercise_category: %{name: category_name}}) do
    [normalize_query(name), normalize_query(category_name)]
  end

  defp exercise_name_search_values(%{name: name}) do
    [normalize_query(name)]
  end

  defp normalize_query(query) when is_binary(query) do
    query
    |> String.trim()
    |> String.downcase()
  end

  defp normalize_query(_query), do: ""

  defp clear_search?(query) when is_binary(query), do: query != ""

  defp clear_search?(_query), do: false
end
