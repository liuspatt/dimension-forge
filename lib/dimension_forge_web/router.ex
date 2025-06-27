defmodule DimensionForgeWeb.Router do
  use DimensionForgeWeb, :router

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/api", DimensionForgeWeb do
    pipe_through(:api)

    post("/validate-key", ApiKeyController, :validate)

    # Image upload API (requires authentication)
    post("/upload", ImageController, :upload)

    # Image metadata and management endpoints
    get("/image/:id", ImageController, :get_image_metadata)
    delete("/image/:id/variants", ImageController, :reset_variants)
    delete("/images/variants", ImageController, :reset_all_variants)
  end

  # Public image delivery endpoints (no authentication required)
  scope "/image", DimensionForgeWeb do
    get("/:project_name/:image_id/:width/:height/:filename", ImageController, :show)
  end

  # Root health check endpoint
  scope "/", DimensionForgeWeb do
    get("/", HealthController, :index)
  end

  # URL-based image resizing endpoint - /300/200/image.webp
  # Expects project_name and image_id as query parameters or headers
  scope "/", DimensionForgeWeb do
    get("/:width/:height/:filename", ImageController, :resize_url)
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:dimension_forge, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through([:fetch_session, :protect_from_forgery])

      live_dashboard("/dashboard", metrics: DimensionForgeWeb.Telemetry)
      forward("/mailbox", Plug.Swoosh.MailboxPreview)
    end
  end
end
