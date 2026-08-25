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
            # rubocop:disable-next Style/CaseEquality
            key === inner_key
          end&.dig(1)

      current_value = value_at_current_key
      if current_value.nil?
        break
      end
    end

    current_value
  end
end
