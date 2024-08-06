# https://gist.github.com/straight-shoota/3ef2fe2f597a4306ef9b84d195f81bf3

macro memoize(type_decl, &block)
  @{{type_decl.var}} : {{ type_decl.type }} | UninitializedMemo = UninitializedMemo::INSTANCE

  def {{type_decl.var}}
    if (value = @{{type_decl.var}}).is_a?(UninitializedMemo)
      @{{type_decl.var}} = begin
        {{block.body}}
      end
    else
      value
    end
  end
end

class UninitializedMemo
  INSTANCE = new
end
