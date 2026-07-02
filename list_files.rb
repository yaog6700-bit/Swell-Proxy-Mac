require 'xcodeproj'
project_path = 'BaoLianDeng.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'BaoLianDeng' }

target.source_build_phase.files.each do |f|
  if f.file_ref && f.file_ref.path && f.file_ref.path.include?('Routing')
    puts "Name: #{f.file_ref.name}, Path: #{f.file_ref.path}, Real Path: #{f.file_ref.real_path}"
  end
end
