require "csv"

require_relative "dataset"

module Datasets
  class LIBSVM < Dataset
    class Record
      attr_reader :label
      attr_reader :features
      def initialize(label, features)
        @label = label
        @features = features
      end

      def [](index)
        @features[index]
      end

      def to_h
        hash = {
          label: @label,
        }
        @features.each_with_index do |feature, i|
          hash[i] = feature
        end
        hash
      end

      def values
        [@label] + @features
      end
    end

    def initialize(name,
                   note: nil,
                   default_feature_value: 0)
      super()
      @dataset_info = fetch_dataset_info(name)
      @file = choose_file(note)
      @default_feature_value = default_feature_value
      @metadata.id = "libsvm-#{normalize_name(name)}"
      @metadata.name = "LIBSVM data: #{name}"
      @metadata.url = "https://www.csie.ntu.edu.tw/~cjlin/libsvmtools/datasets/"
    end

    def each
      return to_enum(__method__) unless block_given?

      open_data do |input|
        csv = CSV.new(input, col_sep: " ")
        csv.each do |row|
          label = parse_label(row.shift)
          features = [@default_feature_value] * @dataset_info.n_features
          row.each do |column|
            next if column.nil?
            index, value = column.split(":", 2)
            features[Integer(index, 10) - 1] = parse_value(value)
          end
          yield(Record.new(label, features))
        end
      end
    end

    private
    def fetch_dataset_info(name)
      list = LIBSVMDatasetList.new
      available_datasets = []
      list.each do |record|
        available_datasets << record.name
        if record.name == name
          return record
        end
      end
      message = "unavailable LIBSVM data: #{name.inspect}: ["
      message << available_datasets.join(", ")
      message << "]"
      raise ArgumentError, message
    end

    def choose_file(note)
      files = @dataset_info.files
      return files.first if note.nil?

      available_notes = []
      @dataset_info.files.find do |file|
        return file if file.note == note
        available_notes << note if file.note
      end

      message = "unavailable note: #{@dataset_info.name}: #{note.inspect}: ["
      message << available_notes.join(", ")
      message << "]"
      raise ArgumentError, message
    end

    def open_data(&block)
      data_path = cache_dir_path + @file.name
      unless data_path.exist?
        download(data_path, @file.url)
      end
      if data_path.extname == ".bz2"
        input, output = IO.pipe
        pid = spawn("bzcat", data_path.to_s, {:out => output})
        begin
          output.close
          yield(input)
        ensure
          input.close
          Process.waitpid(pid)
        end
      else
        File.open(data_path, &block)
      end
    end

    def normalize_name(name)
      name.gsub(/[()]/, "").gsub(/[ _;]+/, "-").downcase
    end

    def parse_label(label)
      labels = label.split(",").collect do |value|
        parse_value(value)
      end
      if labels.size == 1
        labels[0]
      else
        labels
      end
    end

    def parse_value(value)
      if value.include?(".")
        Float(value)
      else
        Integer(value, 10)
      end
    end
  end
end
