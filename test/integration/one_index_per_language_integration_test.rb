require 'test_helper'
require 'elasticsearch/model/globalize/one_index_per_language'

class OneIndexPerLanguageIntegrationTest < Elasticsearch::Test::IntegrationTestCase

  class Article < ActiveRecord::Base
    translates :title
    include Elasticsearch::Model
    include Elasticsearch::Model::Callbacks
    include Elasticsearch::Model::Globalize::OneIndexPerLanguage

    settings index: {number_of_shards: 1, number_of_replicas: 1} do
      globalized_mapping do |locale|
        if locale == :en
          indexes :title, analyzer: 'snowball'
        else
          indexes :title, analyzer: 'cjk'
        end
      end
    end
  end

  context "OneIndexPerLanguage module" do
    setup do
      ActiveRecord::Schema.define(version: 1) do
        create_table :articles do |t|
          t.string :title
        end
        Article.create_translation_table! title: :string
      end
      Article.destroy_all
      Article.__elasticsearch__.create_index! force: true
      a = Article.new
      a.title = 'Search engine'
      Globalize.with_locale(:ja) { a.title = '検索エンジン' }
      a.save!
      Globalize.with_locale(:ja) { Article.create! title: '世界貿易機関 World Trade Organization' }
      Article.create! title: 'Testing code'
      Article.__elasticsearch__.refresh_index!
      sleep 1
    end

    should 'search' do
      Globalize.with_locale(:en) do
        assert_equal 1, Article.search('search').results.total
        assert_equal 0, Article.search('検索').results.total
      end

      Globalize.with_locale(:ja) do
        assert_equal 0, Article.search('search').results.total
        assert_equal 1, Article.search('検索').results.total
      end
    end

    should 'mapping' do
      Globalize.with_locale(:en) do
        assert_equal 1, Article.search('title:testing').results.total
        assert_equal 1, Article.search('title:test').results.total, 'Should be snowball analyzer'
      end

      Globalize.with_locale(:ja) do
        assert_equal 1, Article.search('title:organization').results.total
        assert_equal 0, Article.search('title:organ').results.total, 'Should not be snowball analyzer'
      end
    end
  end
end
