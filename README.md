# Elasticsearch::Model::Globalize

`elasticsearch-model-globalize` library allows you to use `elasticsearch-model` library
with `Globalize` gem.


## Installation

Add this line to your application's Gemfile:

    gem 'elasticsearch-model-globalize'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install elasticsearch-model-globalize


## Usage

There are a few ways to use `elasticsearch-model` with `Globalize`.

This gem has two modules, one is `MultipleFields` and the other is `OneIndexPerLanguage`.
You can choose one for each model to fit your needs by simply including a module.

```ruby
class Item < ActiveRecord::Base
  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks
  include Elasticsearch::Model::Globalize::MultipleFields
  # Or
  # include Elasticsearch::Model::Globalize::OneIndexPerLanguage
end
```


### MultipleFields

`MultipleFields` module creates additional fields for each language.
For example, you have a model like:

```ruby
class Item < ActiveRecord::Base
  translates :name, :description
  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks
  include Elasticsearch::Model::Globalize::MultipleFields

  mapping do
    indexes :id,             type: 'integer'
    indexes :name_ja,        analyzer: 'kuromoji'
    indexes :name_en,        analyzer: 'snowball'
    indexes :description_ja, analyzer: 'kuromoji'
    indexes :description_en, analyzer: 'snowball'
  end
end
```

and you have `:en` and `:ja` for available locales.

`MultipleFields` module creates `name_en`, `name_ja`, `description_en` and `description_ja`
field and stores these fields instead of `name` and `description` fields into Elasticsearch.

You can customize the way to localize field names.

```ruby
# Put this in config/initializers/elasticsearch-model-globalize.rb
Elasticsearch::Model::Globalize::MultipleFields.localized_name do |name, locale|
  "#{locale}_#{name}"
end
```

One thing you have to care about is that put `translates` line before includeing
`Elasticsearch::Model::Globalize::MultipleFields`, otherwise `MultipleFields` module are not able to
know from which fields to derive localized fields.


### OneIndexPerLanguage

`OneIndexPerLanguage` module creates one index per language.
For example, you have a model like:

```ruby
class Item < ActiveRecord::Base
  translates :name, :description
  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks
  include Elasticsearch::Model::Globalize::OneIndexPerLanguage
end
```

and you have `:en` and `:ja` for available locales,

`OneIndexPerLanguage` module creates `items-en` and `items-ja` indices.

You can customize the way to localize index names and document types.

```ruby
# Put this in config/initializers/elasticsearch-model-globalize.rb
Elasticsearch::Model::Globalize::OneIndexPerLanguage.localized_name do |name, locale|
  "#{locale}-#{name}"
end
```

You can use `index_name_base` and `documenty_type_base` in addition to `index_name` and
`document_type`.


You can define mappings using `globalized_maping` as follows:

```ruby
class Item < ActiveRecord::Base
  translates :name, :description
  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks
  include Elasticsearch::Model::OneIndexPerLanguage

  globalized_mapping do |locale|
    analyzer = locale == :ja ? 'kuromoji' : 'snowball'

    indexes :id,          type: 'integer'
    indexes :name,        analyzer: analyzer
    indexes :description, analyzer: analyzer
  end
end
```


## Development and Community

For local development, clone the repository and run bundle install.

To run all tests against a test Elasticsearch cluster, use a command like this:

```sh
curl -# https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-1.2.1.tar.gz | tar xz -C tmp/
SERVER=start TEST_CLUSTER_COMMAND=$PWD/tmp/elasticsearch-1.2.1/bin/elasticsearch bundle exec rake test
```


## Contributing

1. Fork it ( https://github.com/kentaroi/elasticsearch-model-globalize/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
