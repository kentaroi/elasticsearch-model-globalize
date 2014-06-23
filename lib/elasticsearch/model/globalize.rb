require "elasticsearch/model/globalize/version"

module Elasticsearch
  module Model
    module Globalize
      autoload :MultipleFields,      'elasticsearch/model/globalize/multiple_fields'
      autoload :OneIndexPerLanguage, 'elasticsearch/model/globalize/one_index_per_language'
    end
  end
end
