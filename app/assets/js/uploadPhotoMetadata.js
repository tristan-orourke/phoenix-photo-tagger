const files_input = document.getElementById("new_photo_form_images");
if (files_input) {
    files_input.addEventListener("change", updateMetadata);
}

function updateMetadata() {
    const filesInput = document.getElementById("new_photo_form_images");
    const metadataInput = document.getElementById("new_photo_form_file_metadata");
    if (filesInput && filesInput.files && metadataInput) {
        const metadata = Array.from(filesInput.files).map(file => {
            return {
                name: file.name,
                type: file.type,
                size: file.size,
                lastModified: file.lastModified
            };
        });
        metadataInput.value = JSON.stringify(metadata);
    }
}