require 'xcodeproj'
project_path = 'BaoLianDeng.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'BaoLianDeng' }

# Remove wrong files
target.source_build_phase.files.each do |build_file|
  if build_file.file_ref && build_file.file_ref.path
    path = build_file.file_ref.path
    if path.include?('BaoLianDeng/Views/BaoLianDeng') || path.include?('BaoLianDeng/Models/BaoLianDeng')
      build_file.file_ref.remove_from_project
    end
  end
end

project.save
