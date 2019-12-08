module Mutations
  class BaseMutation < GraphQL::Schema::Mutation
    null false

    # The method authenticates the token
    def authenticate_user
      unless context[:current_user]
        return GraphQL::ExecutionError.new(I18n.t('errors.auth.unauthenticated'))
      end
    end
  end
end
