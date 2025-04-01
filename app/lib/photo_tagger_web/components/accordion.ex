defmodule PhotoTaggerWeb.Components.Accordion do
  @moduledoc """
  Provides accordion-related components and helper functions.
  """
  use Phoenix.Component
  alias Phoenix.LiveView.JS

  import PhotoTaggerWeb.CoreComponents, only: [icon: 1]

  @doc """
  Accordion components allows users to show and hide sections of related panel on a page.

  ## Examples

  ```heex
  <.accordion>
    <:trigger>Accordion</:trigger>
    <:panel>Content</:panel>
  </.accordion>
  ```
  """

  attr :class, :any, doc: "Extend existing component styles", default: ""
  attr :controlled, :boolean, default: false
  attr :id, :string, required: true
  attr :rest, :global

  slot :trigger, validate_attrs: false
  slot :panel, validate_attrs: false

  @spec accordion(Socket.assigns()) :: Rendered.t()
  def accordion(assigns) do
    ~H"""
    <div class={["accordion", assigns[:class]]} id={@id} {@rest}>
      <%= for {{trigger, panel}, idx} <- @trigger |> Enum.zip(@panel) |> Enum.with_index() do %>
        <h3>
          <button
            aria-controls={panel_id(@id, idx)}
            aria-expanded={to_string(panel[:default_expanded] == true)}
            class={[
              "accordion-trigger relative w-full [&_.accordion-trigger-icon]:aria-expanded:rotate-180",
              trigger[:class]
            ]}
            id={trigger_id(@id, idx)}
            phx-click={handle_click(assigns, idx)}
            type="button"
            {assigns_to_attributes(trigger, [:class, :icon_name])}
          >
            {render_slot(trigger)}
            <.icon
              class="hero-chevron-down-micro md:hero-chevron-down-mini lg:hero-chevron-down accordion-trigger-icon h-3 w-3 md:h-4 md:w-4 lg:h-5 lg:w-5 absolute right-4 transition-all ease-in-out duration-100 top-1/2 -translate-y-1/2"
              name={trigger[:icon_name] || "hero-chevron-down"}
            />
          </button>
        </h3>
        <div
          class="accordion-panel grid grid-rows-[0fr] data-[expanded]:grid-rows-[1fr]"
          data-expanded={panel[:default_expanded]}
          id={panel_id(@id, idx)}
          role="region"
        >
          <div class="overflow-hidden">
            <div
              class={["accordion-panel-content", panel[:class]]}
              {assigns_to_attributes(panel, [:class, :default_expanded ])}
            >
              {render_slot(panel)}
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp trigger_id(id, idx), do: "#{id}_trigger#{idx}"
  defp panel_id(id, idx), do: "#{id}_panel#{idx}"

  defp handle_click(%{controlled: controlled, id: id}, idx) do
    e_id = Phoenix.HTML.css_escape(id)
    e_trigger_id = trigger_id(id, idx) |> Phoenix.HTML.css_escape()
    e_panel_id = panel_id(id, idx) |> Phoenix.HTML.css_escape()

    op =
      {"aria-expanded", "true", "false"}
      |> JS.toggle_attribute(to: "##{e_trigger_id}")
      |> JS.toggle_attribute({"data-expanded", ""}, to: "##{e_panel_id}")

    if controlled do
      op
      |> JS.set_attribute({"aria-expanded", "false"},
        to: "##{e_id} .accordion-trigger:not(##{e_trigger_id})"
      )
      |> JS.remove_attribute("data-expanded",
        to: "##{e_id} .accordion-panel:not(##{e_panel_id})"
      )
    else
      op
    end
  end
end
