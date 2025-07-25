namespace :code_standards do
  desc "Check code standards violations (read-only)"
  task check: :environment do
    # Directories to check
    directories_to_check = %w[
      app/controllers
      app/models
      app/services
      app/helpers
      app/jobs
      lib
    ]

    def ruby_files_in(directory)
      Dir.glob(Rails.root.join("#{directory}/**/*.rb").to_s)
    end

    # Collect all file paths
    all_files = []
    directories_to_check.each do |directory|
      all_files.concat(ruby_files_in(directory))
    end

    # Use the shared checker
    checker = CodeStandardsChecker.new
    all_violations = checker.check_multiple_files(all_files)

    # Report results
    puts "\n" + "=" * 80
    puts "CODE STANDARDS REPORT"
    puts "=" * 80

    if all_violations.empty?
      puts "✅ All files meet code standards!"
      exit 0
    end

    puts checker.format_violations(all_violations)

    puts "\nTo apply StandardRB formatting: bundle exec standardrb --fix"
    puts "To lint only modified files: rake code_standards:lint_modified"

    puts "\nFORMATTING PREFERENCES (StandardRB compatible - see CLAUDE.md):"
    puts "• Arrays: alphabetical order when order doesn't matter, use %i[] %w[]"
    puts "• Arrays: one per line when over 80 chars, maintain alphabetical order"
    puts "• Method calls: extract variables or break at method chain points"
    puts "• Hash parameters: extract to variables for readability"
    puts "• Long strings: extract to variables or break with backslash"
    puts "• Comments: break at sentence boundaries (StandardRB preserves these)"
    puts "• Avoid parameter alignment - StandardRB collapses whitespace"

    exit 1 if all_violations.any?
  end

  desc "Run StandardRB linter on modified files only"
  task :lint_modified do
    modified_files = `git diff --name-only HEAD`.split("\n").select { |f| f.end_with?(".rb") }

    if modified_files.empty?
      puts "No modified Ruby files to lint."
    else
      puts "Linting #{modified_files.length} modified Ruby files..."
      system("bundle exec standardrb --fix #{modified_files.join(" ")}")
    end
  end

  desc "Full workflow: lint with StandardRB then check standards"
  task :fix_all do
    puts "Step 1: Running StandardRB on all Ruby files..."
    system("bundle exec standardrb --fix app/ lib/ spec/")

    puts "\nStep 2: Checking remaining code standards violations..."
    Rake::Task["code_standards:check"].invoke
  rescue SystemExit
    puts "\nWorkflow complete. Check output above for any remaining violations."
  end
end

desc "Check code standards (alias for code_standards:check)"
task code_standards: "code_standards:check"
