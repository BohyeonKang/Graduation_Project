/*******************************************************************************
Author: joohan.kim (https://blog.naver.com/chacagea)
Associated Filename: main.c
Purpose: CNN Core test (Demo)
Revision History: March 08, 2020 - initial release
*******************************************************************************/

#include <stdio.h>
#include "xil_printf.h"
#include "xil_types.h"
#include "xparameters.h"
#include "xil_io.h"
#include "xil_exception.h"
#include "xtime_l.h"

#define KX 3
#define KY 3
#define ICH 3
#define OCH 16

#define CORE_RUN_ADDR 	0x00
#define F_VAL_ADDR 		0x04
#define W_VAL_ADDR 		0x08
#define B_VAL_ADDR 		0x0C
#define CORE_DONE_ADDR 	0x10
#define RESULT_0_ADDR 	0x14
#define RESULT_ACC_ADDR 0x18

int main()
{
	int inbyte_in;
	int val;
	unsigned int kx, ky; 					// Kernel
	unsigned int ich, och; 					// in / ouput channel
	unsigned int fmap [ICH][KY][KX]; 		// 8b
	unsigned int weight[OCH][ICH][KY][KX]; 	// 8b
	unsigned int bias [OCH]; 				// 8b
	unsigned int mac_result[OCH]; 			// 22b = 16 bit + 4bit ( log (KY*KX 9) ) + 2 bit ( log (ICH 3) )
	unsigned int result[OCH]; 				// 23b = 22 bit + 1bit (bias)
	unsigned int result_for_demo=0; 		// 27b = 23 bit + 4 b ( log (OCH 16) )

	unsigned int result_0_rtl; 				// 23b = 22 bit + 1bit (bias)
	unsigned int result_for_demo_rtl; 		// 27b = 23 bit + 4 b ( log (OCH 16) )

	unsigned int weight_rand_val = 0;
	unsigned int bias_rand_val = 0;
	unsigned int fmap_rand_val = 0;

	double ref_c_run_time;
	double ref_v_run_time;
	XTime ref_c_run_cycle;
	XTime ref_v_run_cycle;

	while (1)
	{
		print ("********************** Matbi CNN Core TEST Start *********************** \r\n ");
		print ("TeraTerm: Please Set Local Echo Mode. \r\n");
		print ("Press '1' Start Demo \r\n");
		print ("Press '2' to exit \r\n");
		print ("Selection:");
		inbyte_in = inbyte ();
		print ("\r\n");
		print ("\r\n");

		XTime tStart, tEnd;

		switch (inbyte_in)
		{
			case '1': // Show all registers
				printf("==== AI Basic, CNN Core. seed_num %d ====\n",tStart);
				srand(tStart);
/////////////////// Random Gen /////////////////////////////
				//generated same value for input each param.
				weight_rand_val = rand()%256;
				bias_rand_val = rand()%256;
				fmap_rand_val = rand()%256;

				// Initial Setting fmap, weight, bias value.
				for (och = 0 ; och < OCH; och ++){
					for(ich = 0; ich < ICH; ich ++){
						for(ky = 0; ky < KY; ky++){
							for(kx = 0; kx < KX; kx++){
								if(och == 0) {
									fmap[ich][ky][kx] = fmap_rand_val;
								}
								weight[och][ich][ky][kx] = weight_rand_val;
							}
						}
					}
					bias[och] = bias_rand_val;
					mac_result[och] = 0;
				}
				result_for_demo =0;
/////////////////// CNN Run in PS /////////////////////////////
				printf("============[REF_C] CNN Run in PS .=============\n");
				XTime_GetTime(&tStart);
				// multiply and accumulate
				for (och = 0 ; och < OCH; och ++){
					for(ich = 0; ich < ICH; ich ++){
						for(ky = 0; ky < KY; ky++){
							for(kx = 0; kx < KX; kx++){
								mac_result[och] += (fmap[ich][ky][kx] * weight[och][ich][ky][kx]);
							}
						}
					}
				}
				// added bias, no activation function
				for (och = 0 ; och < OCH; och ++){
					result[och] = mac_result[och] + bias[och];
					//printf("[och:%d] result : %d\n",och, result[och]);
				}

				// to check result between ref_c vs rtl_v
				for (och = 0 ; och < OCH; och ++){
					result_for_demo += result[och];
				}
				XTime_GetTime(&tEnd);
				ref_c_run_cycle = 2*(tEnd - tStart);
				ref_c_run_time = 1.0 * (tEnd - tStart) / (COUNTS_PER_SECOND/1000000);
				printf("[REF_C] Output took %llu clock cycles.\n", ref_c_run_cycle);
				printf("[REF_C] Output took %.2f us.\n", ref_c_run_time);
				printf("[REF_C] result[0] : %d\n", result[0]);
				printf("[REF_C] result_acc_for_demo : %d\n", result_for_demo);

/////////////////// CNN Run in PL /////////////////////////////
				printf("============[RTL_V] CNN Run in PL .=============\n");
				Xil_Out32 ((u32) (XPAR_CNN_CORE_TEST_CI3_CO_0_BASEADDR + F_VAL_ADDR), (u32) fmap_rand_val);
				Xil_Out32 ((u32) (XPAR_CNN_CORE_TEST_CI3_CO_0_BASEADDR + W_VAL_ADDR), (u32) weight_rand_val);
				Xil_Out32 ((u32) (XPAR_CNN_CORE_TEST_CI3_CO_0_BASEADDR + B_VAL_ADDR), (u32) bias_rand_val);

				XTime_GetTime(&tStart);
				Xil_Out32 ((u32) (XPAR_CNN_CORE_TEST_CI3_CO_0_BASEADDR + CORE_RUN_ADDR), (u32) 1); // run

				while(1) {
					val = (int) Xil_In32 ((u32) (XPAR_CNN_CORE_TEST_CI3_CO_0_BASEADDR + CORE_DONE_ADDR));
					if(val == 1)
						break;
				}
				result_0_rtl = (int) Xil_In32 ((u32) (XPAR_CNN_CORE_TEST_CI3_CO_0_BASEADDR + RESULT_0_ADDR));
				result_for_demo_rtl = (int) Xil_In32 ((u32) (XPAR_CNN_CORE_TEST_CI3_CO_0_BASEADDR + RESULT_ACC_ADDR));
				XTime_GetTime(&tEnd);
				ref_v_run_cycle = 2*(tEnd - tStart);
				ref_v_run_time = 1.0 * (tEnd - tStart) / (COUNTS_PER_SECOND/1000000);
				printf("[RTL_V] Output took %llu clock cycles.\n", ref_v_run_cycle);
				printf("[RTL_V] Output took %.2f us.\n", ref_v_run_time);
				printf("[RTL_V] result[0] : %d\n", result_0_rtl);
				printf("[RTL_V] result_acc_for_demo : %d\n", result_for_demo_rtl);

				if(result[0] != result_0_rtl) {
					printf("[Mismatch] result[0] : %d vs result_0_rtl : %d\n", result[0], result_0_rtl);
					print ("exit \r\n");
					return 0;
				}
				if(result_for_demo != result_for_demo_rtl) {
					printf("[Mismatch] result_for_demo : %d vs result_for_demo_rtl : %d\n", result_for_demo, result_for_demo_rtl);
					print ("exit \r\n");
					return 0;
				}
				printf("[Match] REF_C vs RTL_V \n");
				double perf_ratio = ref_c_run_cycle / ref_v_run_cycle;
				printf("[Match] RTL_V is  %.2f times faster than REF_C  \n", perf_ratio);
				printf("[Match] The difference between RTL_V and REF_C is %.2f us.  \n", ref_c_run_time - ref_v_run_time);
				break;
			case '2': // exit
				print ("exit \r\n");
				return 0;
		}
		print ("\r\n");
	}
    return 0;
}
