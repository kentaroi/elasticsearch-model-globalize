module Elasticsearch
  module Model
    module Globalize
      module MultipleFields
        def self.included(base)
          base.class_eval do
            class << self
              def locales
                @locales ||= I18n.available_locales
              end
            end

            locales.each do |locale|
              translated_attribute_names.each do |name|
                localized_name = MultipleFields.localized_name(name, locale)

                class_eval <<-METHOD, __FILE__, __LINE__ + 1 # Define getter
                def #{localized_name}
                  globalize.stash.contains?(:#{locale}, '#{name}') ? globalize.stash[:#{locale}]['#{name}']
                                                                   : translation_for(:#{locale}, false).try(:read_attribute, '#{name}')
                end
                METHOD

                class_eval <<-METHOD, __FILE__, __LINE__ + 1 # Define setter
                def #{localized_name}=(val)
                  attribute_will_change!(:#{localized_name})
                  write_attribute('#{name}', val, locale: :#{locale})
                end
                METHOD
              end
            end

            translated_attribute_names.each do |name|
              class_eval <<-METHOD, __FILE__, __LINE__ + 1
              def #{name}=(val)
                attribute_will_change!(::Elasticsearch::Model::Globalize::MultipleFields.localized_name('#{name}', ::Globalize.locale))
                write_attribute('#{name}', val)
              end
              METHOD
            end

            def __elasticsearch__ &block
              unless @__elasticsearch__
                @__elasticsearch__ = ::Elasticsearch::Model::Proxy::InstanceMethodsProxy.new(self)
                @__elasticsearch__.extend Elasticsearch::Model::Globalize::MultipleFields::InstanceMethods
              end
              @__elasticsearch__.instance_eval(&block) if block_given?
              @__elasticsearch__
            end
          end
        end

        def self.localized_name(name=nil, locale=nil, &block)
          @localizer = block if block_given?

          @localizer ? @localizer.call(name, locale) : "#{name}_#{locale}"
        end

        module InstanceMethods
          def as_globalized_json(options={})
            h = self.as_json

            translated_attribute_names.each do |name|
              h.delete(name.to_s)

              self.class.locales.each do |locale|
                localized_name = Elasticsearch::Model::Globalize::MultipleFields.localized_name(name, locale)
                h[localized_name] = send(localized_name)
              end
            end
            h
          end

          def as_indexed_json(options={})
            self.as_globalized_json(options.merge root: false)
          end
        end
      end
    end
  end
end
