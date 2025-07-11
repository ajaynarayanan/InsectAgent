# 🐞 InsectAgent

**InsectAgent** is a demo iOS application that demonstrates a hybrid approach to insect recognition by combining traditional vision models with on-device multimodal large language models (MLLMs).

This app runs fully on-device (iOS 18.2+), using:
- A **ResNet18 classifier** trained on the [IP102 dataset](https://openaccess.thecvf.com/content_CVPR_2019/html/Wu_IP102_A_Large-Scale_Benchmark_Dataset_for_Insect_Pest_Recognition_CVPR_2019_paper.html)
- Apple’s [FastVLM](https://arxiv.org/pdf/2412.13303) MLLM

When the confidence from the vision model is low, the app retrieves taxonomic knowledge and uses FastVLM to refine predictions — mimicking how entomologists resolve ambiguity.

---

## 🧠 Paper Abstract (ISVLSI 2025)

> **Insect Agent: Improving Insect Recognition through Dynamic Information Augmentation with Multimodal Large Language Models**
>
> Insect recognition remains a critical challenge for biodiversity monitoring, conservation efforts, and agricultural sustainability. Current computer vision approaches struggle with accurate species identification due to subtle morphological differences.  
> Our analysis reveals that while vision classifiers often fail to predict the correct species as their top choice, the true species is usually included in the top-k predictions.
>
> We introduce **Insect Agent**, a two-stage framework:
> 1. A vision classifier proposes candidate species with confidence scores.
> 2. If confidence is low, the system retrieves relevant expert knowledge and invokes a multimodal language model (MLLM) to refine the prediction.
>
> This dynamic invocation strategy minimizes computational cost while improving classification accuracy. Our experiments show that Insect Agent improves performance by **14.24% on average** compared to vision-only models.

---

## 📱 Application Demo

The demo includes 3 sample images from the IP102 dataset. These can be used to test the full pipeline on-device.

<img src="demo.gif" alt="InsectAgent demo" width="500"/>

---

## ⚡️ Pretrained FastVLM Models

InsectAgent supports multiple pre-trained FastVLM variants:

| Model         | Size  | Use Case                                  |
|---------------|-------|--------------------------------------------|
| FastVLM 0.5B  | Small | Fastest and smallest – ideal for mobile    |
| FastVLM 1.5B  | Medium| Balanced in speed and accuracy             |
| FastVLM 7B    | Large | Most accurate – best for powerful devices  |

### 🔽 Download Instructions

Use the `get_pretrained_mlx_model.sh` script:

1. Make the script executable:

    ```bash
    chmod +x get_pretrained_mlx_model.sh
    ```

2. Download the desired model:

    ```bash
    ./get_pretrained_mlx_model.sh --model 0.5b --dest ./FastVLM/model
    ```

3. Open the project in Xcode, build, and run.

To switch models, rerun the script with a different flag (e.g., `--model 1.5b`) and rebuild.

---

## 📄 License

This project includes software and model components from Apple’s FastVLM and related research projects.

Please refer to the following files for licensing and attribution:

- `LICENSE`
- `LICENSE_MODEL`
- `Acknowledgements`

> ⚠️ Model weights are provided for **non-commercial research use only**.

---

## 📚 Citation

If you use this work or build on it, please cite:

```bibtex
@inproceedings{insectAgent,
  title={Insect Agent: Improving Insect Recognition via Dynamic Knowledge Augmentation Using Multimodal Large Language Models},
  author={Zhao*, Shu and Narayanan Sridhar* and Ajay and Patch, Harland and Narayanan, Vijaykrishnan},
  booktitle={2025 IEEE Computer Society Annual Symposium on VLSI (ISVLSI)},
  year={2025},
  organization={IEEE},
  note={(* indicates equal contribution)}
}
