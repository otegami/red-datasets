#!/usr/bin/env ruby

require 'datasets'

wikipedia = Datasets::Wikipedia.new
wikipedia.clear_cache!
wikipedia.each do |wiki|
  pp wiki.title
end
