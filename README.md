# FPGA-Based Image Processing System with Software-Controlled Filter Selection on the PYNQ-Z2 Platform

## 1. Project Overview

Our project is an FPGA-Based Multi-Image Processing System using the PYNQ-Z2 board. The main aim of our project is to perform different image-processing operations using FPGA hardware and provide a simple software interface through the Jupyter Notebook.

The important feature of our system is that the user can select the required image-processing operation through a software command, without changing the FPGA hardware design. The software provides the input image, selects the required operation, controls the hardware and displays the output, while the FPGA performs the main image-processing operation.

Another important feature is that image processing is performed locally on the PYNQ-Z2 without requiring an internet connection. This approach can be useful in applications such as defence, surveillance and remote monitoring, where continuous internet connectivity may not always be available and image data may need to be processed locally.

## 2. Target Board and Hardware Platform

Our system is based on the **PYNQ-Z2 development board**, which uses the Xilinx Zynq-7000 SoC with the XC7Z020 FPGA device. It has two main sections: the Processing System and the Programmable Logic.

The Processing System contains an ARM Cortex-A9 processor and runs Linux, Python and Jupyter Notebook. It handles software commands, image preparation, hardware control and result display.

The Programmable Logic is the FPGA section where the image-processing operations are implemented in hardware. Therefore, our project combines software control with FPGA-based image processing.

### PYNQ-Z2 Development Board
<img width="1911" height="1188" alt="image" src="https://github.com/user-attachments/assets/39a0d812-9b8c-44c3-b4f1-2db149e4f708" />


*Figure 1: PYNQ-Z2 development board used for the project.*

### Board Specifications

| Parameter | Specification |
|---|---|
| Development Board | PYNQ-Z2 |
| SoC | Xilinx Zynq-7000 |
| FPGA Device | XC7Z020 |
| Processor | ARM Cortex-A9 |
| Input Image Size | 256 × 256 pixels |
| Pixel Format | 8-bit grayscale |
| Total Number of Pixels | 65,536 |
| Design Target Clock | 100 MHz |
| Software Interface | Python and Jupyter Notebook |
| Data Transfer | AXI DMA and AXI4-Stream |
| Filter Selection | AXI GPIO |

## 3. System Working

First, we load the predefined software program containing the functions required to control our system. The user provides an input image through the software. The image is resized to 256 × 256 pixels and converted from a colour image into an 8-bit grayscale image. The prepared image contains 65,536 pixels and is stored in a buffer in the DDR memory of the PYNQ-Z2.

After the image is stored in memory, DMA (Direct Memory Access) transfers the image data from DDR memory toward the FPGA. DMA transfers image data efficiently without requiring the ARM processor to transfer every pixel individually. This allows the processor to focus mainly on software and control tasks.

For communication between the Processing System and the FPGA hardware, our design uses AXI interfaces. AXI4-Lite is mainly used for control and configuration, while AXI4-Stream transfers the continuous pixel data.

Once the image data enters the FPGA, the AXI Broadcaster distributes the input stream to the available image-processing paths. Our system supports four image-processing operations.

- **Gaussian Filter:** Smooths the image and reduces noise.
- **Sobel Filter:** Detects edges and boundaries.
- **Laplacian Filter:** Highlights rapid changes in image intensity and helps identify boundaries.
- **Canny Filter:** Performs detailed edge detection to obtain clearer edge information.

The main feature of our project is software-controlled filter selection. The user selects the required processing path directly from the Jupyter Notebook using software commands.

When a command is executed, the software sends the required control information to the FPGA through AXI GPIO. The corresponding processing and output path is selected without changing or rebuilding the FPGA hardware design.

After the selected image-processing operation is completed, the processed pixel data passes through the corresponding output gate. The output gate controls which processing result is allowed to continue toward the output section. The processed data then passes through an AXI4-Stream FIFO, which provides temporary buffering for the pixel stream.

After the FIFO, the output DMA transfers the processed image back to DDR memory. Once the DMA transfer is completed, the software reads the processed image from the output buffer. The result is then displayed in the Jupyter Notebook.

## 4. User Commands

The following Python commands are used through the Jupyter Notebook to control the image-processing operations.

| Command | Description |
|---|---|
| `run_gaussian()` | Selects and executes the Gaussian filter to smooth the image and reduce noise. |
| `run_sobel()` | Selects and executes the Sobel filter to detect image edges and boundaries. |
| `run_laplacian()` | Selects and executes the Laplacian filter to highlight rapid changes in image intensity. |
| `run_canny()` | Selects and executes the Canny filter for detailed edge detection. |
| `run_all()` | Executes all four image-processing operations in the predefined sequence. |

These commands allow the user to select the required image-processing operation directly from Jupyter Notebook. The software sends the necessary control signals through AXI GPIO, and the FPGA performs the selected operation. The processed image is then transferred back to DDR memory using DMA and displayed in the notebook.

## 5. System Block Diagram

```text
                  ┌────────────────────────┐
                  │       Input Image      │
                  └────────────┬───────────┘
                               │
                               ▼
                  ┌────────────────────────┐
                  │   Image Preparation    │
                  │ Resize and Grayscale   │
                  │    256 × 256, 8-bit    │
                  └────────────┬───────────┘
                               │
                               ▼
                  ┌────────────────────────┐
                  │   DDR Memory (Input)   │
                  └────────────┬───────────┘
                               │
                               ▼
                  ┌────────────────────────┐
                  │    Input AXI DMA       │
                  │        MM2S            │
                  └────────────┬───────────┘
                               │
                               ▼
                  ┌────────────────────────┐
                  │    AXI Broadcaster     │
                  └─────┬─────┬─────┬──────┘
                        │     │     │     │
             ┌──────────┘     │     │     └──────────┐
             ▼                ▼     ▼                ▼
       ┌──────────┐      ┌────────┐ ┌──────────┐ ┌──────────┐
       │ Gaussian │      │ Sobel  │ │Laplacian │ │  Canny   │
       │  Filter  │      │ Filter │ │  Filter  │ │  Filter  │
       └─────┬────┘      └───┬────┘ └────┬─────┘ └────┬─────┘
             └───────────────┴──────┬────┴────────────┘
                                    │
                                    ▼
                         ┌────────────────────────┐
                         │ Output Gate / Selection│
                         │    Controlled by GPIO  │
                         └────────────┬───────────┘
                                      │
                                      ▼
                         ┌────────────────────────┐
                         │    AXI Stream FIFO     │
                         └────────────┬───────────┘
                                      │
                                      ▼
                         ┌────────────────────────┐
                         │    Output AXI DMA      │
                         │         S2MM           │
                         └────────────┬───────────┘
                                      │
                                      ▼
                         ┌────────────────────────┐
                         │   DDR Memory (Output)  │
                         └────────────┬───────────┘
                                      │
                                      ▼
                         ┌────────────────────────┐
                         │    Python / Jupyter    │
                         │    Displayed Result    │
                         └────────────────────────┘

       Jupyter Notebook ──► AXI GPIO ──► Filter / Output Selection
```

### Complete Data Flow

**Input Image → Image Preparation → DDR Memory → Input DMA → AXI4-Stream → AXI Broadcaster → Selected Image Processing → Output Gate → FIFO → Output DMA → DDR Memory → Python → Displayed Result**

## 6. IP Cores Used

The system uses AXI-based IP cores and custom image-processing hardware to transfer image data, control the processing paths and return the processed image to memory.

| No. | IP Core / Hardware Block | Purpose |
|---:|---|---|
| 1 | Zynq7 Processing System | Provides the ARM processor, DDR memory access and Processing System interfaces. |
| 2 | AXI DMA | Transfers image data between DDR memory and FPGA processing hardware. |
| 3 | AXI4-Stream Broadcaster | Distributes the input pixel stream to the available processing paths. |
| 4 | Gaussian Filter IP | Smooths the image and reduces noise. |
| 5 | Sobel Filter IP | Detects image edges and boundaries. |
| 6 | Laplacian Filter IP | Highlights rapid changes in image intensity. |
| 7 | Canny Filter IP | Performs detailed edge detection. |
| 8 | AXI GPIO | Transfers software filter-selection and control signals. |
| 9 | AXI4-Stream FIFO | Temporarily buffers the processed pixel stream. |
| 10 | Output Selection / Gating Logic | Selects the processing result that continues to the output path. |
| 11 | AXI SmartConnect| Connects AXI master and slave interfaces. |
| 12 | Processor System Reset, if used | Provides reset signals for the Processing System and Programmable Logic. |


## 7. Results

The system supports four image-processing operations: Gaussian, Sobel, Laplacian and Canny. The input image is prepared in grayscale format, processed by the selected FPGA hardware path and displayed through Jupyter Notebook.

### 7.1 Input Image

![Input Image](images/input-image.png)

*Figure 2: Input image supplied to the image-processing system.*

### 7.2 Gaussian Filter Output

![Gaussian Filter Output](images/gaussian-output.png)

*Figure 3: Gaussian filter output showing image smoothing and noise reduction.*

### 7.3 Sobel Filter Output

![Sobel Filter Output](images/sobel-output.png)

*Figure 4: Sobel filter output highlighting image edges and boundaries.*

### 7.4 Laplacian Filter Output

![Laplacian Filter Output](images/laplacian-output.png)

*Figure 5: Laplacian filter output highlighting rapid changes in image intensity.*

### 7.5 Canny Filter Output

![Canny Filter Output](images/canny-output.png)

*Figure 6: Canny filter output showing detected edges.*


### 7.7 FPGA Implementation Results

The project report records the following implementation and timing results.

| Parameter | Reported Result |
|---|---:|
| Worst Negative Slack (WNS) | +0.128 ns |
| Total Negative Slack (TNS) | 0 ns |
| Failing Timing Endpoints | 0 out of 114,010 |
| Look-Up Tables (LUTs) | 19,052 (36%) |
| Flip-Flops | 36,478 (34%) |
| Block RAM (BRAM) | 7 (5%) |
| DSP Slices | 0 |
| Estimated On-Chip Power | 1.773 W |
| Junction Temperature | 45.4 °C |
| Thermal Margin | 39.6 °C |

### 7.8 Result Observations

- **Gaussian:** Reduces speckle noise and smooths the image.
- **Sobel:** Highlights edges and boundaries, although some texture noise may remain.
- **Laplacian:** Highlights rapid intensity changes and boundaries, with some residual texture noise.
- **Canny:** Produces cleaner, thinner and more continuous edges using non-maximum suppression, double thresholding and hysteresis. The implementation described in the project report uses a local-neighbourhood approximation for hysteresis.

## 8. Example Operation

For example, if the user wants to perform Sobel processing, the user provides the input image and executes `run_sobel()` in Jupyter Notebook. The software sends the required filter-selection information through AXI GPIO.

The input DMA transfers the image from DDR memory to the FPGA. The selected Sobel processing path processes the pixel stream. The output gate and FIFO pass the result to the output DMA, which transfers it back to DDR memory. Python then displays the processed image.

The same overall process is used for Gaussian, Laplacian and Canny processing. The user can execute `run_all()` to run all four filters in the predefined sequence.

## 9. Key Features

- Four image-processing operations: Gaussian, Sobel, Laplacian and Canny.
- Software-controlled filter selection through Jupyter Notebook.
- FPGA-based image processing on the PYNQ-Z2 board.
- AXI DMA for efficient image-data transfer.
- AXI4-Stream for continuous pixel-data transfer.
- AXI GPIO for filter and output selection.
- Python interface for controlling the system and displaying results.
- Local image processing without requiring an internet connection for the processing operation.

## 10. Applications

Our system may be useful in the following applications:

- Defence and surveillance systems.
- Remote monitoring.
- Image processing in locations with limited internet connectivity.
- Edge detection and image preprocessing for computer-vision systems.

These are potential application areas and do not imply that the project has been deployed in each application.

## 11. Conclusion

Our project demonstrates a software-controlled FPGA-based multi-image-processing system using the PYNQ-Z2 platform. The user provides an input image and selects the required operation through Jupyter Notebook. Python handles software control, AXI GPIO provides filter selection, DMA transfers image data, AXI4-Stream carries the pixel stream, and the FPGA performs the selected image-processing operation.

The processed result is transferred back to memory and displayed in the notebook. The main concept of our project is to support multiple image-processing operations with software-based filter selection, efficient FPGA hardware processing and local operation without requiring internet connectivity.

## 12. References

1. Xilinx/AMD, *Zynq-7000 SoC Technical Reference Manual*.
2. Xilinx/AMD, *AXI DMA Product Guide*.
3. PYNQ Project Documentation, *PYNQ-Z2 and Python/Jupyter-Based FPGA Development*.
4. John Canny, “A Computational Approach to Edge Detection,” *IEEE Transactions on Pattern Analysis and Machine Intelligence*, 1986.

---

## 13. Project Team and Academic Details

1. **Pravin Bhangare**
2. **Harshada Dalvi**
3. **Swayam Sawant**
4. **Vaishnavi Bauchkar**

**Project Guide:** Prof. Satendra Mane

**Department:** Electronics and Telecommunication Engineering

**Institute:** Vidyalankar Institute of Technology, Mumbai

**Academic Year:** 2026–2027

