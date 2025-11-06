mod gpu;

fn main() {
    // Example usage of GPU functions
    #[cfg(target_os = "windows")]
    {
        match gpu::get_gpu_usage() {
            Ok(usages) => {
                for (i, &usage) in usages.iter().enumerate() {
                    println!("GPU {} Usage: {:.2}%", i, usage);
                }
            }
            Err(e) => println!("Error getting GPU usage: {}", e),
        }
    }
}
