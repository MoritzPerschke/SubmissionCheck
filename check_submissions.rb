#!/usr/bin/env ruby

require 'optparse'
require 'zip'
require 'fileutils'
require 'syslog/logger'
require 'pathname'

# I know using globals isn't great, but for these i don't care
# Define a simple logger with concise format
$logger = Logger.new(STDOUT)
$logger.level = Logger::DEBUG

$logger.formatter = proc { |severity, datetime, progname, msg|
  "[#{severity}] #{msg}\n"
}

# Define possible command line options
$options = {}
OptionParser.new do |opts|
  opts.on("-d", "--dir DIRECTORY", "Specify a directory to work in (default: current dir)") do |dir|
    $options[:directory] = dir
  end

  opts.on("-o", "--output-dir OUTPUT_DIR", "Specify a directory to output unzipped files to (default: './submissions')") do |out|
    $options[:out] = out 
  end
  opts.on("-c", "--cs-identifier", "Create directories named after students csXXXXXX identifier instead of their name") do |cs|
    $options[:cs] = true
  end
end.parse!

# In case there are more than one zip files in the current dir let the user decide
def find_zip_current_dir()
  file_to_extract = nil
  archives = Dir.glob("./*.zip")
  archives += Dir.glob("./*.tar.gz")

  if archives.size() > 1
    $logger.error("More than one zip file found, please specify:")
    archives.each_with_index do |file, index|
      puts "\t#{index}: #{file}"
    end
    index_selected = Integer(gets)
    file_to_extract = archives[index_selected]
  else
    file_to_extract = archives[0]
  end

  return file_to_extract
end

# Extract the zip file and restructure
def extract_and_restructure_zip(file, target)
  # Match an uppercase letter followed by at least one lowercase letter, followed by 
  # an underscore and then again uppercase followed by one or more lowercase
  # matches e.g. '/Gurney_Halleck', as contained in zip downloaded from olat:
  # ita_Assignment_...'/Gurney_Halleck'_cs...
  pattern = nil
  if $options[:cs]
    pattern = /cs[a-z]{2}[0-9]+/
  else
    pattern = /([A-Z][a-z]+)_([A-Z][a-z]+)/
  end

  Zip::File.open(file) do |zip|
    zip.each do |entry|
      directory = String(entry.name.match(pattern))
      filename = File.basename(Pathname.new(entry.name))
      target_path = File.join(target, directory)
      target_filepath = File.join(target_path, filename)

      $logger.debug("\n\tTarget: #{target}\n\tDirectory: #{directory}\n\tFilename: #{filename}\n\tTarget Path: #{target_path}\n\tFull: #{target_filepath}")

      # Maybe I misread the docs for this method, but giving the 'target_path' results in the 
      # directory for a student not being created
      FileUtils.mkdir_p(File.dirname(target_filepath)) unless Dir.exist?(target_filepath)
      zip.extract(entry, target_filepath)
    end
  end
end

def main
  directory = nil
  output_dir = nil

  if ARGV.length() > 0
    directory = Pathname.new(ARGV[0])
    $logger.info("Working in \'#{directory}\'")
  elsif $options[:directory] != nil
    directory = Pathname.new($options[:directory])
    $logger.info("Working in \'#{directory}\'")
  end

  if $options[:out] != nil
    output_dir = $options[:out]
  else
    output_dir = Pathname.new('./submissions')
  end
    
  zip_file = Pathname.new(find_zip_current_dir())
  if zip_file.extname == ".zip"
    $logger.info("Extracting '#{zip_file}' to '#{output_dir}'")
    extract_and_restructure_zip(zip_file, output_dir)
  else
    $logger.error("Archive type #{zip_file.extname} not implemented")
  end
    
end

main if __FILE__ == $0
