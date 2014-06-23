require 'test_helper'
require 'elasticsearch/model/globalize/multiple_fields'

class MultipleFieldsIntegrationTest < Elasticsearch::Test::IntegrationTestCase

  class Article < ActiveRecord::Base
    translates :title
    @locales = [:en, :ja]
    include Elasticsearch::Model
    include Elasticsearch::Model::Callbacks
    include Elasticsearch::Model::Globalize::MultipleFields

    settings index: {number_of_shards: 1, number_of_replicas: 1} do
      mapping do
        indexes :title_en, analyzer: 'snowball'
        indexes :title_ja, analyzer: 'cjk'
      end
    end
  end

  context "Mulfield module" do
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
    end

    should 'search' do
      assert_equal 1, Article.search('search').results.total
      assert_equal 1, Article.search('検索').results.total
    end

    should 'mapping' do
      assert_equal 1, Article.search('title_en:testing').results.total
      assert_equal 1, Article.search('title_en:test').results.total, 'Should be snowball analyzer'
      assert_equal 1, Article.search('title_ja:organization').results.total
      assert_equal 0, Article.search('title_ja:organ').results.total, 'Should not be snowball analyzer'
    end
  end
end
