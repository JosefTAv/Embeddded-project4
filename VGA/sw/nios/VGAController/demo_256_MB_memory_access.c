#include <assert.h>
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "io.h"
#include "system.h"

#define HPS_0_BRIDGES_BASE (0x0000)            /* address_span_expander base address from system.h (ADAPT TO YOUR DESIGN) */
#define HPS_0_BRIDGES_SPAN (256 * 1024 * 1024) /* address_span_expander span from system.h (ADAPT TO YOUR DESIGN) */

#define BASE_ADDR 0x10000840

/* Runtime registers */
#define INIT_REG      (BASE_ADDR + 0)
#define NF_REG        (BASE_ADDR + 4)
#define FB_BASE_REG   (BASE_ADDR + 8)
#define FB_ID_REG     (BASE_ADDR + 12)
#define STATE_REG     (BASE_ADDR + 16)

/* Configuration registers */
#define VGA_HBP_REG   (BASE_ADDR + 20)
#define VGA_HFP_REG   (BASE_ADDR + 24)
#define VGA VBP_REG   (BASE_ADDR + 28)
#define VGA_VFP_REG   (BASE_ADDR + 32)
#define VGA_HDATA_REG (BASE_ADDR + 36)
#define VGA_VDATA_REG (BASE_ADDR + 40)
#define VGA_HSYNC_REG (BASE_ADDR + 44)
#define VGA_VSYNC_REG (BASE_ADDR + 48)

/* Debug registers */
#define DEBUG1_REG    (BASE_ADDR + 52)
#define DEBUG2_REG    (BASE_ADDR + 56)
#define DEBUG3_REG    (BASE_ADDR + 60)

/* FSM States */
#define STATE_RESET 0
#define STATE_IDLE  1
#define STATE_BUSY  2
#define STATE_ERROR 3

#define ONE_MB (1024 * 1024)

#define NUM_FRAMEBUFFERS (2)
#define FRAMEBUFFER_SIZE (640*480)
#define BUFFER_TRANSFER_SIZE 4096

static uint32_t* sdram = (uint32_t*) 0x0;

int validate(uint32_t in) {
	in = ((in & 0xFF000000) >> 24) |
		 ((in & 0x00FF0000) >> 8)  |
		 ((in & 0x0000FF00) << 8)  |
		 ((in & 0x000000FF) << 24);

	uint8_t sum = 0;

	for(uint8_t j = 0; j < 30; j++) {
		sum += ((in >> j) & 0b1);
	}

	return (sum & 0b11) == (in >> 30);
}

int main(void) {
	uint32_t vga_state = 0;
	uint32_t fifo_state = 0;

	uint32_t counter = 0;
	uint32_t pixel = 0;

	vga_state = IORD_32DIRECT(STATE_REG, 0);

    char* filename = "/mnt/host/frames.bin";
    FILE* file = fopen(filename, "r");

    if(!file) {
    	printf("Error: Framebuffers binary not accessible: %s\n", filename);
    }

    assert(NUM_FRAMEBUFFERS * FRAMEBUFFER_SIZE <= HPS_0_BRIDGES_SPAN);
    assert(NUM_FRAMEBUFFERS * FRAMEBUFFER_SIZE % BUFFER_TRANSFER_SIZE == 0);

    if(sdram[0] != 0x40010594) { // Power lost! We must retransfer the framebuffer to the SDRAM... (Linux is little Endian btw)
		uint32_t num_chunks = NUM_FRAMEBUFFERS * FRAMEBUFFER_SIZE / BUFFER_TRANSFER_SIZE;

		for(uint32_t i = 0; i < num_chunks; i++) {
			uint32_t tx_errors = 0;

			fread(sdram + i*BUFFER_TRANSFER_SIZE, sizeof(uint32_t), BUFFER_TRANSFER_SIZE, file); // Transfer preserves endianness

			for(uint32_t j = 0; j < BUFFER_TRANSFER_SIZE; j++) {
				if(!validate(sdram[i*BUFFER_TRANSFER_SIZE + j])) {
					tx_errors++;
				}
			}

			printf("Transferring framebuffers chunks... %" PRIu32 "/%" PRIu32 ": %" PRIu32 " errors\n", i+1, num_chunks, tx_errors);
		}
    }

    fclose(file);


	printf("Initial framebuffer successfully uploaded to SDRAM!\n");

	uint32_t sram_errors = 0;

	for(uint32_t i = 0; i < NUM_FRAMEBUFFERS*FRAMEBUFFER_SIZE; i++) {
		if(!validate(sdram[i])) {
			sram_errors++;
		}
	}

	printf("SDRAM content checked: %" PRIu32 " errors!\n", sram_errors);

	vga_state = IORD_32DIRECT(STATE_REG, 0);
	//assert(vga_state == STATE_RESET);

 	IOWR_32DIRECT(INIT_REG, 0, 1);
	IOWR_32DIRECT(INIT_REG, 0, 0);

	vga_state = IORD_32DIRECT(STATE_REG, 0);
	//assert(vga_state == STATE_IDLE);

	IOWR_32DIRECT(FB_BASE_REG, 0, 0);
	IOWR_32DIRECT(FB_ID_REG, 0, 0);

	IOWR_32DIRECT(NF_REG, 0, 1);
	vga_state = IORD_32DIRECT(STATE_REG, 0);

	uint32_t successes = 0;
	uint32_t errors = 0;

	while(1) {
		pixel = IORD_32DIRECT(DEBUG1_REG, 0);
		counter = IORD_32DIRECT(DEBUG2_REG, 0);
		fifo_state = IORD_32DIRECT(DEBUG3_REG, 0);
		vga_state = IORD_32DIRECT(STATE_REG, 0);


		if(!validate(pixel)) {
			errors++;
		} else {
			successes++;
		}
	}

    return EXIT_SUCCESS;
}
