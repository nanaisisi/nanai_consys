use windows::Win32::Graphics::Dxgi::*;
use windows::Win32::Graphics::Direct3D11::*;
use windows::Win32::Foundation::*;
use std::collections::HashMap;

// GPU usage via Windows DXGI API, grouped by physical GPU
pub fn get_gpu_usage() -> Result<Vec<f64>, Box<dyn std::error::Error>> {
    unsafe {
        // Create DXGI Factory
        let factory: IDXGIFactory = CreateDXGIFactory()?;

        let mut gpu_map: HashMap<String, Vec<f64>> = HashMap::new();
        let mut adapter_index = 0;

        // Enumerate adapters
        while let Ok(adapter) = factory.EnumAdapters(adapter_index) {
            adapter_index += 1;

            // Get adapter description
            let mut desc = DXGI_ADAPTER_DESC::default();
            adapter.GetDesc(&mut desc)?;

            // Convert adapter LUID to string for grouping
            let luid = format!("{:08x}{:08x}", desc.AdapterLuid.HighPart, desc.AdapterLuid.LowPart);

            // For now, we'll use a placeholder usage value since DXGI doesn't provide real-time usage
            // In a real implementation, you'd need additional APIs like NVAPI or AMD GPU Services
            let placeholder_usage = 0.0; // Placeholder - real usage requires additional APIs

            gpu_map.entry(luid).or_insert(Vec::new()).push(placeholder_usage);

            // Limit to first few adapters to avoid infinite loop
            if adapter_index >= 10 {
                break;
            }
        }

        // Calculate average usage per physical GPU (placeholder values)
        let mut usages: Vec<f64> = gpu_map.values()
            .map(|vals| vals.iter().sum::<f64>() / vals.len() as f64)
            .collect();
        usages.sort_by(|a, b| a.partial_cmp(b).unwrap());

        Ok(usages)
    }
}