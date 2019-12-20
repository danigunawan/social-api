class GraphqlController < ApplicationController
  # If accessing from outside this domain, nullify the session
  # This allows for outside API access while preventing CSRF attacks,
  # but you'll have to authenticate your user separately
  # protect_from_forgery with: :null_session
  require 'json_web_token'

  def execute
    variables = ensure_hash(params[:variables])
    query = params[:query]
    operation_name = params[:operationName]
    context = {
        # Query context goes here, for example:
        current_user: current_user,
        decoded_token: decoded_token
    }
    result = SocialApiSchema.execute(query, variables: variables, context: context, operation_name: operation_name)
    render json: result
  rescue => e
    raise e unless Rails.env.development?
    handle_error_in_development e
  end

  def current_user
    @current_user = nil
    if decoded_token
      data = decoded_token
      p data[:user_id].present?
      user = User.find_by_id(data[:user_id]) if data[:user_id].present?
      if data[:user_id].present? && data[:token].present? && !user.nil? && !user.sessions.where(status: true).find_by(token: data[:token]).nil?
        @current_user ||= user
      end
    end
  end

  def decoded_token
    header = request.headers['Authorization']
    header = header.split(' ').last if header
    if header
      begin
        @decoded_token ||= JsonWebToken.decode(header)
      rescue ActiveRecord::RecordNotFound => e
        raise GraphQL::ExecutionError.new(e.message)
      rescue JWT::DecodeError => e
        raise GraphQL::ExecutionError.new(e.message)
      rescue StandardError => e
        raise GraphQL::ExecutionError.new(e.message)
      end
    end
  end

  private

  # Handle form data, JSON body, or a blank value
  def ensure_hash(ambiguous_param)
    case ambiguous_param
    when String
      if ambiguous_param.present?
        ensure_hash(JSON.parse(ambiguous_param))
      else
        {}
      end
    when Hash, ActionController::Parameters
      ambiguous_param
    when nil
      {}
    else
      raise ArgumentError, "Unexpected parameter: #{ambiguous_param}"
    end
  end

  def handle_error_in_development(e)
    logger.error e.message
    logger.error e.backtrace.join("\n")

    render json: {error: {message: e.message, backtrace: e.backtrace}, data: {}}, status: 500
  end
end
