defmodule PhotoTaggerWeb.Router do
  use PhotoTaggerWeb, :router
  import Phoenix.LiveDashboard.Router
  import Plug.BasicAuth

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

  pipeline :admin do
    # plug :basic_auth, Application.compile_env(:photo_tagger, :basic_auth)
    plug :put_layout, html: {PhotoTaggerWeb.Layouts, :admin}
  end

  scope "/", PhotoTaggerWeb do
    pipe_through :browser

    live "/", GalleryLive.Main, :public
    live "/folders", GalleryLive.Main, :public

    live "/folders/:folder", GalleryLive.Main, :public
    live "/folders/:folder/photos", GalleryLive.Main, :public
    live "/folders/:folder/photos/:photo_id", GalleryLive.Main, :public
    live "/folders/:folder/photos/:photo_id/drift", GalleryLive.Drift, :folder
    live "/photos", GalleryLive.Main, :public
    live "/photos/:photo_id", GalleryLive.Main, :public
    live "/photos/:photo_id/drift", GalleryLive.Drift, :all_folders
  end

  scope "/admin", PhotoTaggerWeb do
    pipe_through [:browser, :admin]

    live_dashboard "/dashboard", metrics: PhotoTaggerWeb.Telemetry

    resources "/photos", PhotoController, only: [:new, :create, :edit, :update, :delete]
    live "/", GalleryLive.Main, :index
    live "/folders", GalleryLive.Main, :index
    live "/folders/:folder", GalleryLive.Main, :folder
    get "/edit-folders", FolderController, :edit_folders
    post "/folders", FolderController, :create
    put "/folders/:folder", FolderController, :update
    post "/folders/:folder/rename", FolderController, :rename
    delete "/folders/:folder", FolderController, :delete
    live "/photos", GalleryLive.Main, :photos
    live "/photos/:photo_id", GalleryLive.Main, :photos
    post "/photos/:photo_id/tags", PhotoController, :add_tag_main
    delete "/photos/:photo_id/tags/:tag", PhotoController, :remove_tag_main
    live "/folders/:folder/photos", GalleryLive.Main, :folder
    live "/folders/:folder/photos/:photo_id", GalleryLive.Main, :folder
    get "/edit-tags", TagController, :edit_tags
    put "/tags/:tag", TagController, :update
    delete "/tags/:tag", TagController, :delete
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
    # import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      # live_dashboard "/dashboard", metrics: PhotoTaggerWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
