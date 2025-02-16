# frozen_string_literal: true

require 'active_support/all'
# load("#{Dir.home}/code/dotfiles/utils/ruby/tapp.rb")

module SqlUtils
  FORMATTING_NEEDED_PATTERNS = [
    'db_host:',
    "-- format\n",
    ' Load (',
  ].freeze

  def reformat_match?(sql)
    FORMATTING_NEEDED_PATTERNS.any? { sql.include?(_1) }
  end

  # rubocop:disable Metrics/MethodLength, Metrics/PerceivedComplexity
  def format_sql_if_necessary
    sql = File.read('personal/sql.sql')
    original_sql = sql.dup

    if !reformat_match?(sql)
      return
    end

    sql.sub!(/\A.*?(?=SELECT)/, '')

    query, variables_string = sql.split(%r{ +/\*.+\*/ *| +(?=\[\[)})

    query.delete!('"')
    query.gsub!('-- format', '')

    prepared_statement_bind_parameters =
      if variables_string
        variables_string = variables_string[1..-2]
        variables_string.
          scan(/(?=\[.*?, ([^\]]+)\])/).
          flatten.
          map do |interpolation_variable|
            if interpolation_variable.is_a?(String)
              interpolation_variable.tr('"', "'")
            else
              interpolation_variable
            end
          end
      else
        []
      end

    prepared_statement_bind_parameters.each.with_index(1) do |bind_param, param_number|
      query.sub!("$#{param_number}", bind_param)
    end

    File.write('personal/sql_unformatted.sql', query)
    formatted_query = `cat personal/sql_unformatted.sql | sql-formatter --language=postgresql`

    if formatted_query.nil? || formatted_query.empty?
      # If there was an error, restore original SQL.
      File.write('personal/sql.sql', original_sql)
    else
      if File.exist?('personal/sql_substitutions.txt')
        sql_substitution_pairs = File.read('personal/sql_substitutions.txt').split(/====*/)
        sql_substitution_pairs.each do |sql_substitution_pair|
          original_sql_fragment, new_sql_fragment = sql_substitution_pair.split(/----*/)

          if original_sql_fragment.present?
            formatted_query.gsub!(original_sql_fragment, new_sql_fragment)
          end
        end
      end

      formatted_query.squeeze!("\n")

      File.write('personal/sql.sql', formatted_query)
    end
  end
  # rubocop:enable Metrics/MethodLength, Metrics/PerceivedComplexity
end
