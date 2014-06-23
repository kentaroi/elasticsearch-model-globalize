require 'test_helper'
require 'elasticsearch/model/globalize/one_index_per_language'

class OneIndexPerLanguageTest < Test::Unit::TestCase
  class Article < ActiveRecord::Base
    translates :title, :body
    @locales = [:en, :ja]
    include Elasticsearch::Model
    include Elasticsearch::Model::Callbacks
    include Elasticsearch::Model::Globalize::OneIndexPerLanguage
  end

  def setup
    ActiveRecord::Base.establish_connection( :adapter => 'sqlite3', :database => ":memory:" )
    logger = ::Logger.new(STDERR)
    logger.formatter = lambda { |s, d, p, m| "#{m.ansi(:faint, :cyan)}\n" }
    ActiveRecord::Base.logger = logger unless ENV['QUIET']

    ActiveRecord::LogSubscriber.colorize_logging = false
    ActiveRecord::Migration.verbose = false

    tracer = ::Logger.new(STDERR)
    tracer.formatter = lambda { |s, d, p, m| "#{m.gsub(/^.*$/) { |n| '   ' + n }.ansi(:faint)}\n" }


    ActiveRecord::Schema.define(version: 1) do
      create_table :articles do |t|
        t.string :title
        t.text :body
        t.string :code
      end
      Article.create_translation_table! title: :string, body: :text
    end
    I18n.enforce_available_locales = true
    I18n.available_locales = [:en, :ja]
  end

  def test_create
    a = Article.new
    a.title = 'title'
    a.__elasticsearch__.client.expects(:index).with { |value|
      value[:index] == 'one_index_per_language_test-articles-en' &&
      value[:type] == 'article-en' &&
      value[:body].count == 4 &&
      value[:body].has_key?('id') &&
      value[:body]['title'] == 'title' &&
      value[:body]['body'] == nil &&
      value[:body]['code'] == nil
    }
    a.save
  end

  def test_create_multiple_locales
    a = Article.new
    a.title = 'title'
    Globalize.with_locale(:ja) { a.title = 'タイトル' }
    a.__elasticsearch__.client.expects(:index).with { |value|
      value[:index] == 'one_index_per_language_test-articles-en' &&
      value[:type] == 'article-en' &&
      value[:body].count == 4 &&
      value[:body].has_key?('id') &&
      value[:body]['title'] == 'title' &&
      value[:body]['body'] == nil &&
      value[:body]['code'] == nil
    }
    a.__elasticsearch__.client.expects(:index).with { |value|
      value[:index] == 'one_index_per_language_test-articles-ja' &&
      value[:type] == 'article-ja' &&
      value[:body].count == 4 &&
      value[:body].has_key?('id') &&
      value[:body]['title'] == 'タイトル' &&
      value[:body]['body'] == nil &&
      value[:body]['code'] == nil
    }
    a.save
  end

  def test_create_with_no_translation_field
    a = Article.new
    a.title = 'title'
    a.code = 'code'
    a.__elasticsearch__.client.expects(:index).with { |value|
      value[:index] == 'one_index_per_language_test-articles-en' &&
      value[:type] == 'article-en' &&
      value[:body].count == 4 &&
      value[:body].has_key?('id') &&
      value[:body]['title'] == 'title' &&
      value[:body]['body'] == nil &&
      value[:body]['code'] == 'code'
    }
    a.save
  end

  def test_update
    a = Article.new
    a.__elasticsearch__.stubs(:index_document)
    a.title = 'title'
    a.body = 'body'
    a.save
    a.title = 'new title'
    a.__elasticsearch__.client.expects(:update).with { |value|
      value[:index] == 'one_index_per_language_test-articles-en' &&
      value[:type] == 'article-en' &&
      value[:id] == a.id &&
      value[:body][:doc].count == 1 &&
      value[:body][:doc]['title'] == 'new title'
    }
    a.save
  end

  def test_update_with_new_locale
    a = Article.new
    a.__elasticsearch__.client.stubs(:index)
    a.title = 'title'
    a.body = 'body'
    a.save
    a.title = 'new title'
    Globalize.with_locale(:ja) { a.title = 'タイトル' }
    a.__elasticsearch__.client.expects(:update).with { |value|
      value[:index] == 'one_index_per_language_test-articles-en' &&
      value[:type] == 'article-en' &&
      value[:id] == a.id &&
      value[:body][:doc].count == 1 &&
      value[:body][:doc]['title'] == 'new title'
    }
    a.__elasticsearch__.client.expects(:index).with { |value|
      value[:index] == 'one_index_per_language_test-articles-ja' &&
      value[:type] == 'article-ja' &&
      value[:body].count == 4 &&
      value[:body].has_key?('id') &&
      value[:body]['title'] == 'タイトル' &&
      value[:body]['body'] == nil &&
      value[:body]['code'] == nil
    }
    a.save
  end
end
