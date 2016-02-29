module Elasticsearch
  module Model
    module Globalize
      module OneIndexPerLanguage

        def self.included(base)
          base.class_eval do
            self.__elasticsearch__.class_eval do
              include Elasticsearch::Model::Globalize::OneIndexPerLanguage::ClassMethods
            end

            class << self
              [:globalized_mapping, :globalized_mappings, :import_globally, :index_name_base, :index_name_base=, :document_type_base, :document_type_base=].each do |m|
                delegate m, to: :__elasticsearch__
              end
            end

            def __elasticsearch__ &block
              unless @__elasticsearch__
                @__elasticsearch__ = ::Elasticsearch::Model::Proxy::InstanceMethodsProxy.new(self)
                @__elasticsearch__.extend Elasticsearch::Model::Globalize::OneIndexPerLanguage::InstanceMethods
              end
              @__elasticsearch__.instance_eval(&block) if block_given?
              @__elasticsearch__
            end

            before_update :update_existence_of_documents
            before_save   :update_changed_attributes_by_locale
          end
        end

        def self.localized_name(name=nil, locale=nil, &block)
          block_given? ? block.call(name, locale) : "#{name}-#{locale}"
        end

        module ClassMethods
          def index_name_base name=nil
            @index_name_base = name and index_names.clear if name
            @index_name_base || self.model_name.collection.gsub(/\//, '-')
          end

          def index_name_base=(name)
            index_names.clear
            @index_name_base = name
          end

          def document_type_base name=nil
            @document_type_base = name and document_types.clear if name
            @document_type_base || self.model_name.element
          end

          def document_type_base=(name)
            document_types.clear
            @document_type_base = name
          end

          def index_name name=nil
            @index_name = name if name
            @index_name || index_names[::Globalize.locale] ||=
              ::Elasticsearch::Model::Globalize::OneIndexPerLanguage.localized_name(index_name_base, ::Globalize.locale)
          end

          def index_names
            @index_names ||= {}
          end

          def document_type name=nil
            @document_type = name if name
            @document_type || document_types[::Globalize.locale] ||=
              ::Elasticsearch::Model::Globalize::OneIndexPerLanguage.localized_name(document_type_base, ::Globalize.locale)
          end

          def document_types
            @document_types ||= {}
          end

          def globalized_mapping(options={}, &block)
            unless @globalized_mapping
              @globalized_mapping = ActiveSupport::HashWithIndifferentAccess.new
              target.__elasticsearch__.class_eval <<-RUBY, __FILE__, __LINE__ + 1
              def mapping
                @globalized_mapping[::Globalize.locale]
              end
              alias :mappings :mapping
              RUBY
            end
            I18n.available_locales.each do |locale|
              @globalized_mapping[locale] ||= ::Elasticsearch::Model::Indexing::Mappings.new(
                ::Elasticsearch::Model::Globalize::OneIndexPerLanguage.localized_name(document_type_base, locale), options)

              if block_given?
                @globalized_mapping[locale].options.update(options)

                @globalized_mapping[locale].instance_exec(locale, &block)
              end
            end
            @globalized_mapping
          end
          alias :globalized_mappings :globalized_mapping

          def import(options={}, &block)
            current_locale_only = options.delete(:current_locale_only)
            if current_locale_only
              super(options, &block)
            else
              errors = Hash.new
              I18n.available_locales.each do |locale|
                super_options = options.clone
                ::Globalize.with_locale(locale) do
                  errors[locale] = super(super_options, &block)
                end
              end
              self.find_each do |record|
                (I18n.available_locales - record.translations.pluck(:locale).map(&:to_sym)).each do |locale|
                  ::Globalize.with_locale(locale) do
                    record.__elasticsearch__.delete_document(current_locale_only: true)
                  end
                end
              end
              errors
            end
          end
        end

        module InstanceMethods
          attr_accessor :existence_of_documents, :changed_attributes_by_locale

          def changed_attributes_by_locale
            @changed_attributes_by_locale ||= ActiveSupport::HashWithIndifferentAccess.new
          end

          def existence_of_documents
            @existence_of_documents ||= ActiveSupport::HashWithIndifferentAccess.new
          end

          def index_name_base name=nil
            @index_name_base = name || @index_name_base || self.class.index_name_base
          end

          def index_name_base=(name)
            @index_name_base = name
          end

          def document_type_base name=nil
            @document_type_base = name || @document_type_base || self.class.document_type_base
          end

          def document_type_base=(name)
            @document_type_base = name
          end

          def index_name
            self.class.index_name
          end

          def document_type
            self.class.document_type
          end

          def index_document(options={})
            current_locale_only = options.delete(:current_locale_only)
            if current_locale_only
              super(options)
            else
              changed_attributes_by_locale.keys.each do |locale|
                ::Globalize.with_locale(locale) do
                  super(options)
                end
              end
            end
          end

          def update_document(options={})
            changed_attributes_by_locale.keys.each do |locale|
              ::Globalize.with_locale(locale) do
                if existence_of_documents[locale]
                  attributes = if respond_to?(:as_indexed_json)
                    changed_attributes_by_locale[locale].select{ |k, v| as_indexed_json.keys.include? k }
                  else
                    changed_attributes_by_locale[locale]
                  end

                  client.update(
                    { index: index_name,
                      type: document_type,
                      id: self.id,
                      body: { doc: attributes } }.merge(options)
                  )
                else
                  index_document(current_locale_only: true)
                end
              end
            end
          end

          def delete_document(options={})
            current_locale_only = options.delete(:current_locale_only)
            if current_locale_only
              super(options)
            else
              translations.pluck(:locale).each do |locale|
                ::Globalize.with_locale(locale) do
                  super(options)
                end
              end
            end
          end
        end

        # This method actually checks existence of translations in database
        # Therefore, database and elasticsearch must be synced.
        def update_existence_of_documents
          __elasticsearch__.existence_of_documents.clear
          translations.each do |t|
            __elasticsearch__.existence_of_documents[t.locale] = true if t.persisted?
          end
          true
        end

        def update_changed_attributes_by_locale
          __elasticsearch__.changed_attributes_by_locale.clear

          common_changed_attributes = Hash[ changes.map{ |key, value| [key, value.last] } ]
          translated_attribute_names.each { |k| common_changed_attributes.delete(k) }

          globalize.stash.reject{ |locale, attrs| attrs.empty? }.each do |locale, attrs|
            __elasticsearch__.changed_attributes_by_locale[locale] = attrs.merge(common_changed_attributes)
          end
          true
        end
      end
    end
  end
end
