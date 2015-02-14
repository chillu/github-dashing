require 'dotenv'

if ENV['DOTENV_FILE']
  Dotenv.load ENV['DOTENV_FILE']
else
  Dotenv.load
end