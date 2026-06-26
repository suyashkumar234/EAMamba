#!/bin/bash
#SBATCH --partition=gpu
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --gres=gpu:1
#SBATCH --time=12:00:00
#SBATCH --job-name=gopro_complete
#SBATCH --output=complete_evaluation_%j.log
#SBATCH --error=complete_evaluation_%j.err

source /home/apps/miniconda3/bin/activate
conda activate eamamba

cd /home/suyash.kumar.mec22.itbhu/EAMamba

MODEL_PATH="/home/suyash.kumar.mec22.itbhu/gopro.pth"
RESULTS_DIR="/home/suyash.kumar.mec22.itbhu/gopro-results"

echo "=========================================="
echo "COMPLETE EVALUATION - All Post-Processing Methods"
echo "Dataset: GoPro Test Set (1111 images)"
echo "Started at: $(date)"
echo "=========================================="
echo ""

# Create results summary file
SUMMARY_FILE="${RESULTS_DIR}/COMPLETE_RESULTS_SUMMARY.txt"
echo "GoPro Deblurring - Complete Evaluation Results" > ${SUMMARY_FILE}
echo "Date: $(date)" >> ${SUMMARY_FILE}
echo "Model: ${MODEL_PATH}" >> ${SUMMARY_FILE}
echo "========================================" >> ${SUMMARY_FILE}
echo "" >> ${SUMMARY_FILE}

# Function to extract PSNR and SSIM from result files
extract_metrics() {
    local result_dir=$1
    local method_name=$2

    if [ -d "${result_dir}" ]; then
        psnr_file="${result_dir}/PSNR.txt"
        ssim_file="${result_dir}/SSIM.txt"

        if [ -f "${psnr_file}" ] && [ -f "${ssim_file}" ]; then
            psnr=$(grep "AVG-result:" ${psnr_file} | tail -1 | awk '{print $2}')
            ssim=$(grep "AVG-result:" ${ssim_file} | tail -1 | awk '{print $2}')
            time=$(grep "AVG-Time:" ${psnr_file} | tail -1 | awk '{print $2}')

            echo "${method_name}|${psnr}|${ssim}|${time}"
        else
            echo "${method_name}|N/A|N/A|N/A"
        fi
    else
        echo "${method_name}|N/A|N/A|N/A"
    fi
}

# Array to store all results
declare -a RESULTS

# ============================================
# 1. BASELINE (Skip if already done)
# ============================================
echo "----------------------------------------"
echo "1. BASELINE EVALUATION"
echo "----------------------------------------"
if [ ! -d "${RESULTS_DIR}/test-GoPro-results" ]; then
    echo "Running baseline evaluation..."
    python -u test.py \
        --model ${MODEL_PATH} \
        --dataset GoPro \
        --save
    echo "Baseline completed at: $(date)"
else
    echo "Baseline already exists, skipping..."
fi
echo ""
RESULTS+=("$(extract_metrics "${RESULTS_DIR}/test-GoPro-results" "Baseline")")

# ============================================
# 2. SELF-ENSEMBLE
# ============================================
echo "----------------------------------------"
echo "2. SELF-ENSEMBLE (Test-Time Augmentation)"
echo "Expected: +0.15 to +0.30 dB improvement"
echo "----------------------------------------"
python -u test.py \
    --model ${MODEL_PATH} \
    --dataset GoPro \
    --ensemble \
    --save
echo "Self-ensemble completed at: $(date)"
echo ""
RESULTS+=("$(extract_metrics "${RESULTS_DIR}/test-GoPro-results" "Self-Ensemble")")

# ============================================
# 3. UNSHARP MASKING
# ============================================
echo "----------------------------------------"
echo "3. UNSHARP MASKING"
echo "Expected: +0.03 to +0.08 dB improvement"
echo "----------------------------------------"
python -u test_postprocess.py \
    --model ${MODEL_PATH} \
    --dataset GoPro \
    --postprocess unsharp \
    --save
echo "Unsharp masking completed at: $(date)"
echo ""
RESULTS+=("$(extract_metrics "${RESULTS_DIR}/test-GoPro-results-unsharp" "Unsharp Mask")")

# ============================================
# 4. GUIDED FILTER
# ============================================
echo "----------------------------------------"
echo "4. GUIDED FILTER (Edge-Preserving)"
echo "Expected: Better SSIM, artifact reduction"
echo "----------------------------------------"
python -u test_postprocess.py \
    --model ${MODEL_PATH} \
    --dataset GoPro \
    --postprocess guided \
    --save
echo "Guided filter completed at: $(date)"
echo ""
RESULTS+=("$(extract_metrics "${RESULTS_DIR}/test-GoPro-results-guided" "Guided Filter")")

# ============================================
# 5. BILATERAL FILTER
# ============================================
echo "----------------------------------------"
echo "5. BILATERAL FILTER (Noise Reduction)"
echo "Expected: Better SSIM, smoother results"
echo "----------------------------------------"
python -u test_postprocess.py \
    --model ${MODEL_PATH} \
    --dataset GoPro \
    --postprocess bilateral \
    --save
echo "Bilateral filter completed at: $(date)"
echo ""
RESULTS+=("$(extract_metrics "${RESULTS_DIR}/test-GoPro-results-bilateral" "Bilateral Filter")")

# ============================================
# 6. FREQUENCY SEPARATION
# ============================================
echo "----------------------------------------"
echo "6. FREQUENCY SEPARATION (Detail Enhancement)"
echo "Expected: +0.05 to +0.10 dB improvement"
echo "----------------------------------------"
python -u test_postprocess.py \
    --model ${MODEL_PATH} \
    --dataset GoPro \
    --postprocess frequency \
    --save
echo "Frequency separation completed at: $(date)"
echo ""
RESULTS+=("$(extract_metrics "${RESULTS_DIR}/test-GoPro-results-frequency" "Frequency Sep.")")

# ============================================
# 7. CLAHE (Contrast Enhancement)
# ============================================
echo "----------------------------------------"
echo "7. CLAHE (Adaptive Contrast Enhancement)"
echo "Expected: Better visual contrast"
echo "----------------------------------------"
python -u test_postprocess.py \
    --model ${MODEL_PATH} \
    --dataset GoPro \
    --postprocess clahe \
    --save
echo "CLAHE completed at: $(date)"
echo ""
RESULTS+=("$(extract_metrics "${RESULTS_DIR}/test-GoPro-results-clahe" "CLAHE")")

# ============================================
# 8. COMBINED POST-PROCESSING
# ============================================
echo "----------------------------------------"
echo "8. COMBINED POST-PROCESSING"
echo "Methods: Bilateral + Frequency + Unsharp"
echo "Expected: +0.08 to +0.15 dB improvement"
echo "----------------------------------------"
python -u test_postprocess.py \
    --model ${MODEL_PATH} \
    --dataset GoPro \
    --postprocess combined \
    --save
echo "Combined post-processing completed at: $(date)"
echo ""
RESULTS+=("$(extract_metrics "${RESULTS_DIR}/test-GoPro-results-combined" "Combined PP")")

# ============================================
# 9. BEST: ENSEMBLE + COMBINED
# ============================================
echo "----------------------------------------"
echo "9. BEST CONFIGURATION"
echo "Methods: Self-Ensemble + Combined Post-Processing"
echo "Expected: +0.25 to +0.40 dB improvement"
echo "----------------------------------------"
python -u test_postprocess.py \
    --model ${MODEL_PATH} \
    --dataset GoPro \
    --ensemble \
    --postprocess combined \
    --save
echo "Best configuration completed at: $(date)"
echo ""
RESULTS+=("$(extract_metrics "${RESULTS_DIR}/test-GoPro-results-combined" "Ensemble + Combined")")

# ============================================
# GENERATE COMPARATIVE RESULTS
# ============================================
echo ""
echo "=========================================="
echo "ALL EVALUATIONS COMPLETED!"
echo "Finished at: $(date)"
echo "=========================================="
echo ""

# Print results table to console and file
{
    echo ""
    echo "=========================================="
    echo "COMPARATIVE RESULTS SUMMARY"
    echo "=========================================="
    echo ""
    printf "%-25s | %-10s | %-10s | %-12s\n" "Method" "PSNR (dB)" "SSIM" "Time (s)"
    echo "--------------------------------------------------------------------------------"

    # Find baseline values for comparison
    baseline_psnr=""
    baseline_ssim=""

    for result in "${RESULTS[@]}"; do
        IFS='|' read -r method psnr ssim time <<< "$result"

        if [ "$method" == "Baseline" ]; then
            baseline_psnr=$psnr
            baseline_ssim=$ssim
            printf "%-25s | %-10s | %-10s | %-12s\n" "$method" "$psnr" "$ssim" "$time"
        fi
    done

    echo "--------------------------------------------------------------------------------"

    # Print other results with improvements
    for result in "${RESULTS[@]}"; do
        IFS='|' read -r method psnr ssim time <<< "$result"

        if [ "$method" != "Baseline" ] && [ "$psnr" != "N/A" ]; then
            # Calculate improvements
            if [ -n "$baseline_psnr" ]; then
                psnr_diff=$(echo "$psnr - $baseline_psnr" | bc -l)
                ssim_diff=$(echo "$ssim - $baseline_ssim" | bc -l)
                printf "%-25s | %-10s | %-10s | %-12s | Δ: +%.4f / +%.4f\n" "$method" "$psnr" "$ssim" "$time" "$psnr_diff" "$ssim_diff"
            else
                printf "%-25s | %-10s | %-10s | %-12s\n" "$method" "$psnr" "$ssim" "$time"
            fi
        fi
    done

    echo "=================================================================================="
    echo ""
    echo "NOTES:"
    echo "- Baseline: Original model without any post-processing"
    echo "- Self-Ensemble: 4x geometric augmentation (4x slower)"
    echo "- Unsharp Mask: Edge and detail sharpening"
    echo "- Guided Filter: Edge-preserving smoothing"
    echo "- Bilateral Filter: Noise reduction with edge preservation"
    echo "- Frequency Sep.: High-frequency detail enhancement"
    echo "- CLAHE: Adaptive contrast enhancement"
    echo "- Combined PP: Multi-stage pipeline (Bilateral + Frequency + Unsharp)"
    echo "- Ensemble + Combined: Best of both worlds"
    echo ""
    echo "RECOMMENDATIONS:"
    echo "- For best PSNR/SSIM: Use 'Ensemble + Combined'"
    echo "- For fast improvement: Use 'Self-Ensemble' alone"
    echo "- For efficiency: Use 'Combined PP' (small overhead, good gains)"
    echo "- For visual quality: Use 'Frequency Sep.' or 'Combined PP'"
    echo ""
    echo "Results saved in: ${RESULTS_DIR}"
    echo "Individual result folders:"
    echo "  - test-GoPro-results (baseline)"
    echo "  - test-GoPro-results (self-ensemble, overwrites baseline)"
    echo "  - test-GoPro-results-unsharp"
    echo "  - test-GoPro-results-guided"
    echo "  - test-GoPro-results-bilateral"
    echo "  - test-GoPro-results-frequency"
    echo "  - test-GoPro-results-clahe"
    echo "  - test-GoPro-results-combined"
    echo ""

} | tee -a ${SUMMARY_FILE}

echo "Complete summary saved to: ${SUMMARY_FILE}"
echo ""
echo "=========================================="
echo "EVALUATION COMPLETE!"
echo "=========================================="
