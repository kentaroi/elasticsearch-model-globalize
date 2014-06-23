require 'test_helper'
require 'elasticsearch/model/globalize/multiple_fields'

class MultipleFieldsTest < Test::Unit::TestCase
  class Article < ActiveRecord::Base
    translates :title, :body
    @locales = [:en, :ja]
    include Elasticsearch::Model
    include Elasticsearch::Model::Callbacks
    include Elasticsearch::Model::Globalize::MultipleFields
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

  def test_multiple_fields_attribute
    a = Article.new
    assert_nil a.title
    a.title = 'English'
    assert_equal 'English', a.title
    assert_equal 'English', a.title_en
    assert_nil a.title_ja
    assert_equal 2, a.changes.keys.count
    assert a.changes.has_key?(:title_en)
    assert a.changes.has_key?(:title)

    Globalize.with_locale(:ja) {
      assert_nil a.title
      a.title = '日本語'
      assert_equal '日本語', a.title
      assert_equal '日本語', a.title_ja
      assert_equal 'English', a.title_en
      assert_equal 3, a.changes.keys.count
      assert a.changes.has_key?(:title_en)
      assert a.changes.has_key?(:title_ja)
      assert a.changes.has_key?(:title)
    }
    assert_equal 'English', a.title
    assert_equal 'English', a.title_en
    assert_equal '日本語', a.title_ja

    a.title_en = 'English title'
    assert_equal 'English title', a.title_en
    a.title_ja = '日本語タイトル'
    assert_equal '日本語タイトル', a.title_ja
    assert_equal 'English title', a.title
    assert_equal '日本語タイトル', Globalize.with_locale(:ja){ a.title }
  end

  def test_create
    a = Article.new
    a.title = 'title'
    assert_equal 'title', a.title_en
    a.__elasticsearch__.client.expects(:index).with { |value|
      value[:index] == 'multiple_fields_test-articles' &&
      value[:type] == 'article' &&
      value[:body].count == 6 &&
      value[:body].has_key?('id') &&
      value[:body]['title_en'] == 'title' &&
      value[:body]['title_ja'] == nil &&
      value[:body]['body_en'] == nil &&
      value[:body]['body_ja'] == nil &&
      value[:body]['code'] == nil
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
      value[:index] == 'multiple_fields_test-articles' &&
      value[:type] == 'article' &&
      value[:id] == a.id &&
      value[:body][:doc].count == 1 &&
      value[:body][:doc]['title_en'] == 'new title'
    }
    a.save
  end

  def test_update_with_no_translation_field
    a = Article.new
    a.__elasticsearch__.stubs(:index_document)
    a.title = 'title'
    a.body = 'body'
    a.code = 'code'
    a.save
    a.title = 'new title'
    a.code = 'no derived fields'
    a.__elasticsearch__.client.expects(:update).with { |value|
      value[:index] == 'multiple_fields_test-articles' &&
      value[:type] == 'article' &&
      value[:id] == a.id &&
      value[:body][:doc].count == 2 &&
      value[:body][:doc]['title_en'] == 'new title'
      value[:body][:doc]['code'] == 'no derived fields'
    }
    a.save
  end
end
