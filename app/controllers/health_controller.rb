class HealthController < ApplicationController
  # GET /health
  def show
    render json: { status: "ok", service: "shipping_support_ai" }
  end
end
