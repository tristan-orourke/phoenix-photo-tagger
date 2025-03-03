defmodule PhotoTaggerWeb.Router do
  use PhotoTaggerWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PhotoTaggerWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", PhotoTaggerWeb do
    pipe_through :browser

    resources "/photos", PhotoController, only: [:new, :create, :edit, :update, :delete]

    get "/", PhotoController, :main
    get "/folders", PhotoController, :main
    get "/folders/:folder", PhotoController, :main
    get "/edit-folders", PhotoController, :edit_folders
    post "/folders/:folder/rename", PhotoController, :rename_folder
    delete "/folders/:folder", PhotoController, :delete_folder
    get "/photos", PhotoController, :main
    get "/photos/:photo_id", PhotoController, :main
    post "/photos/:photo_id/tags", PhotoController, :add_tag_main
    delete "/photos/:photo_id/tags/:tag", PhotoController, :remove_tag_main
    get "/folders/:folder/photos", PhotoController, :main
    get "/folders/:folder/photos/:photo_id", PhotoController, :main
    get "/edit-tags", PhotoController, :edit_tags
    put "/tags/:tag", PhotoController, :update_tag
    delete "/tags/:tag", PhotoController, :delete_tag
  end

  # Other scopes may use custom stacks.
  # scope "/api", PhotoTaggerWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:photo_tagger, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: PhotoTaggerWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
