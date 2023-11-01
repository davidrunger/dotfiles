# load "#{Dir.home}/code/dotfiles/tools/opensearch_explorer.rb"

# Example usage:
#
# opensearch_exlorer = OpensearchExplorer.new
# opensearch_exlorer.mapping(index: "english_texts_development").tapp

class OpensearchExplorer
  def initialize
    @connection =
      Faraday.new(
        url: "http://localhost:9200",
        headers: { "Content-Type" => "application/json" },
      )
  end

  # GET /_cat/indices
  def indices
    response_body { @connection.get("/_cat/indices") }
  end

  # GET /my-index-000001/_mapping
  def mapping(index:)
    response_body { @connection.get("/#{index}/_mapping") }
  end

  # POST /<index>/_search
  def search(index:, query:, explain: nil)
    response_body do
      post_json(
        Addressable::URI.new(
          path: "/#{index}/_search",
          query: { "explain" => explain }.compact.to_query,
        ).to_s,
        query,
      )
    end
  end

  # POST /<index>/_explain/<id>
  def explain(index:, id:, query:)
    response_body do
      post_json(
        "/#{index}/_explain/#{id}",
        query,
      )
    end
  end

  # GET /<target>/_validate/<query>
  def validate(index:, query:)
    response_body do
      get_json(
        "/#{index}/_validate/query?explain=true",
        query,
      )
    end
  end

  private

  def response_body
    response = yield

    if response.headers["content-type"].match?(%r{\bapplication/json\b})
      JSON.parse(response.body)
    else
      response.body
    end
  end

  def post_json(path, data)
    @connection.post(
      path,
      data.to_json,
      "Content-Type" => "application/json",
    )
  end

  def get_json(path, data)
    @connection.get(path) do |request|
      request.body = data.to_json
      request.headers["Content-Type"] = "application/json"
    end
  end
end
