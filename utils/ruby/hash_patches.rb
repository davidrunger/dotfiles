# frozen_string_literal: true

class Hash
  # [dig] with [c]ase equality
  #
  # Example:
  # hash = {
  #   "GET" =>
  #     {
  #       "/user/auth/google_oauth2/callback?" => {
  #         code: 499,
  #         headers: {},
  #         body_string: "",
  #       },
  #     },
  # }
  # hash.digc("GET", %r{/user/auth/google_oauth2/callback\?}).tapp
  def digc(*keys)
    current_value = self

    keys.tapp.each do |key|
      value_at_current_key =
        current_value.tapp.
          detect do |inner_key, _value|
            # rubocop:disable Style/CaseEquality
            inner_key.tapp === key.tapp
            # rubocop:enable Style/CaseEquality
          end&.second

      if value_at_current_key.tapp.nil?
        return nil
      elsif value_at_current_key.is_a?(Hash)
        current_value = value_at_current_key
      end
    end

    current_value
  end
end
