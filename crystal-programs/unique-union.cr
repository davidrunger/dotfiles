#!/usr/bin/env crystal

def unique_union(set1 : String, set2 : String) : Array(String)
  set1_words = set1.split
  set2_words = set2.split

  (set1_words | set2_words).sort
end

if ARGV.size == 2
  unique_union(ARGV[0], ARGV[1]).each { |item| puts(item) }
else
  puts "Usage: unique-union \"first list of words\" \"second list of words\""
  exit(1)
end
