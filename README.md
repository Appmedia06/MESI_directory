# MESI_directory
A directory-based MESI protocol cache coherence system.

## Configuration

### CPU
* 2 cores
* RISC-V instruction
### Cache
* Size: 128B
* 4 Sets
* 4-way associativity
### Memory
* Size: 2kB
* Block size: 64 bits
### Interconnect
* crossbar
### FPGA
* ZYNQ-Z2 (xc7z020clg400-1)

## System architecture

<img src='https://github.com/Appmedia06/MESI_directory/blob/main/img/system_architecture.png' width=700/>

## Cache architecture

<img src='https://github.com/Appmedia06/MESI_directory/blob/main/img/cache.png' width=550/>

<img src='https://github.com/Appmedia06/MESI_directory/blob/main/img/address.png' width=550/>

## Transaction
| Transaction | Goal of requestor |
| -------- | -------- | 
| GetShared(Get_S)     | Obtain block in Shared (read-only) state     | 
| GetModified (Get_M)     | Obtain block in Modified (read-only) state     | 
| PutShared (Put_S)    | Evict block in Shared state     | 
| PutExclusive (Put_E)     | Evict block in Exclusive state     | 
| PutModified (Put_M)    | 	Evict block in Modified state     | 

## FSM

* The state diagram of a CPU issuing requests to its cache
<img src='https://github.com/Appmedia06/MESI_directory/blob/main/img/CPU_FSM.png' width=550/>

* The state diagram of receiving requests from the caches of other CPUs
<img src='https://github.com/Appmedia06/MESI_directory/blob/main/img/forward_FSM.png' width=550/>

> [Cache Coherency & I/O ordering](https://hackmd.io/@qwe661234/r1BDYhVHo#MESI-protocol)

## Transition Table

### Cache controller
<img src='https://github.com/Appmedia06/MESI_directory/blob/main/img/cache_controller.png' width=550/>

### Directory
<img src='https://github.com/Appmedia06/MESI_directory/blob/main/img/directory.png' width=550/>

> [A Primer on Memory Consistency and Cache Coherence](https://link.springer.com/content/pdf/10.1007/978-3-031-01764-3.pdf)



## Testbench
In `tb.v`, I designed 23 read and write instructions that cover scenarios such as local CPU read/write hits and misses, forwarded reads/writes from other CPUs, invalidation, LRU replacement policy, and other possible situations represented in the above FSM and transition table.

If all tests pass, you will be rewarded with a cute Pikachu.

<img src='https://github.com/Appmedia06/MESI_directory/blob/main/img/testpass.png' width=550/>

### Synthesis & Implementation

### Utilization

| Resource | Utilization  |
| -------- | -------- |
| LUT     | 2045     |
| FF     | 1396     |
| IO     | 6     |
| BUFG     | 1     |

### device
<img src='https://github.com/Appmedia06/MESI_directory/blob/main/img/device.png' width=450/>

### Schematic
<img src='https://github.com/Appmedia06/MESI_directory/blob/main/img/schematic.png' width=450/>


