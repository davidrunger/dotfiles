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

    keys.each do |key|
      value_at_current_key =
        current_value.
          detect do |inner_key, _value|
            # rubocop:disable Style/CaseEquality
            key === inner_key
            # rubocop:enable Style/CaseEquality
          end&.dig(1)

      if value_at_current_key.nil?
        return nil
      else
        current_value = value_at_current_key
      end
    end

    current_value
  end
end
