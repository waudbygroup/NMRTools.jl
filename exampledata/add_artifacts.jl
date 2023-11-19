# don't actually run this - it's a collection of the commands used to upload example data to github gists
# and update the Artifacts.toml file

artifact_id = artifact_from_directory("/Users/chris/Documents/Work/NMRTools/additional-data/1D_1H")
gist = upload_to_gist(artifact_id)
add_artifact!("Artifacts.toml", "1D_1H", gist, lazy=true)

artifact_id = artifact_from_directory("/Users/chris/Documents/Work/NMRTools/additional-data/1D_19F")
gist = upload_to_gist(artifact_id)
add_artifact!("Artifacts.toml", "1D_19F", gist, lazy=true)

artifact_id = artifact_from_directory("/Users/chris/Documents/Work/NMRTools/additional-data/1D_19F_titration")
gist = upload_to_gist(artifact_id)
add_artifact!("Artifacts.toml", "1D_19F_titration", gist, lazy=true)

artifact_id = artifact_from_directory("/Users/chris/Documents/Work/NMRTools/additional-data/2D_HN")
gist = upload_to_gist(artifact_id)
add_artifact!("Artifacts.toml", "2D_HN", gist, lazy=true)

artifact_id = artifact_from_directory("/Users/chris/Documents/Work/NMRTools/additional-data/2D_HN_titration")
gist = upload_to_gist(artifact_id)
add_artifact!("Artifacts.toml", "2D_HN_titration", gist, lazy=true)

