#include <iomanip>
#include<iostream>
#include<fstream>
#include<random>

void cornergen64(uint64_t*p64, int cornerN);
void cornergen32(uint32_t*p32, int cornerN);

bool sequence_corner_gen_fpu32_64(
	uint64_t rnd1_i,
	uint64_t rnd2_i,
	uint64_t rnd3_i,
	uint64_t rnd4_i,
	uint8_t vsew_i,
	uint8_t op_group_i,
	uint8_t op_ctrl_i,
	uint8_t vxrm_i,
	uint8_t scenario_id_i,
	uint8_t setcorner,	//setcorner=0: single corner mode off | setcorner =/= 0: single corner mode on
	//setcorner=[1-3]: selected position in 64bit format, setcorner=[1:6]:selected position in 32bit format
	uint64_t &src1_data_o,
	uint64_t &src2_data_o,
	uint64_t &src3_data_o){

	uint64_t f64[3];
	f64[0]=rnd1_i;
	f64[1]=rnd2_i;
	f64[2]=rnd3_i;

	uint32_t f32[6];
	uint64_t shift=0xffffffff;
	f32[0]=rnd1_i;
	f32[1]=(rnd1_i&(shift<<32))>>32;
	f32[2]=rnd2_i;
	f32[3]=(rnd2_i&(shift<<32))>>32;
	f32[4]=rnd3_i;
	f32[5]=(rnd3_i&(shift<<32))>>32;

	uint64_t * p64=&f64[0];
	uint32_t * p32=&f32[0];

	if (vsew_i==2){
		if (setcorner==0){
			cornergen32(p32,rnd4_i&(0xf));
			cornergen32(p32+1,(rnd4_i&(0xf<<4))>>4);
			cornergen32(p32+2,(rnd4_i&(0xf<<8))>>8);
			cornergen32(p32+3,(rnd4_i&(0xf<<12))>>12);
			cornergen32(p32+4,(rnd4_i&(0xf<<16))>>16);
			cornergen32(p32+5,(rnd4_i&(0xf<<20))>>20);
		} else {
			cornergen32(p32+setcorner-1,rnd4_i&(0xf));
//			printf("fix: %d\n",setcorner);
//			printf("p: %p\n",p32);
			for (int i=0;i<6;i++){
//				printf("p+%d: %p\n",i,p32+i);
//				printf("*p+%d: %x\n\n",i,*(p32+i));
			}
//			printf("p+fix: %p\n",p32+setcorner);
		}
		p64 = (uint64_t *)p32;
		src1_data_o=*(p64);
		src2_data_o=*(p64+1);
		src3_data_o=*(p64+2);
	} else if (vsew_i==3) {
		if (setcorner==0){
			cornergen64(p64,rnd4_i&(0xf));
			cornergen64(p64+1,(rnd4_i&(0xf<<4))>>4);
			cornergen64(p64+2,(rnd4_i&(0xf<<8))>>8);
		} else {
			cornergen64(p64+setcorner-1,rnd4_i&(0xf));
		}
		src1_data_o=*p64;
		src2_data_o=*(p64+1);
		src3_data_o=*(p64+2);
	}

	return 0;
}

void cornergen64(uint64_t*p64, int cornerN){
//	printf("CornerN %d\n",cornerN);
        switch(cornerN){
        case 0: //0
	case 1:
                *p64=0;
		break;
        case 2: //-0
		*p64=0x8000000000000000;
		break;
	case 3: //qNan
	case 4:
		*p64=(*p64)|0x7ff8000000000000;
		break;
	case 5: //sNan
	case 6:
		*p64=((*p64)&0xfff7ffffffffffff)|0x7ff0000000000000;
		break;
	case 7: //+inf
	case 8:
		*p64=0x7ff0000000000000;
		break;
	case 9: //-inf
		*p64=0xfff0000000000000;
		break;
	case 10: //+MAXFLOAT
		*p64=0x7fefffffffffffff;
		break;
	case 11: //-MAXFLOAT
		*p64=0xffefffffffffffff;
		break;
	case 12: //+subnormal
	case 13:
		*p64=(*p64)&0xfffffffffffff;
		break;
	case 14: //-subnormal
	case 15:
		*p64=((*p64)&0xfffffffffffff)|0x8000000000000000;
		break;
	}
}

void cornergen32(uint32_t*p32, int cornerN){
//	printf("CornerN: %d\n",cornerN);
        switch(cornerN){
        case 0: //0
	case 1:
		*p32=0;
                break;
        case 2: //-0
                *p32=0x80000000;
                break;
        case 3: //qNan
	case 4:
                *p32=(*p32)|0xffc00000;
                break;
        case 5: //sNan
	case 6:
                *p32=((*p32)&0x003fffff)|0xff800000;
                break;
        case 7: //+inf
	case 8:
                *p32=0x7f800000;
                break;
        case 9: //-inf
                *p32=0xff800000;
                break;
        case 10: //+MAXFLOAT
                *p32=0x7f7fffff;
                break;
        case 11: //-MAXFLOAT
                *p32=0xff7fffff;
                break;
        case 12: //+subnormal
	case 13:
		*p32=((*p32)&0x007fffff);
                break;
        case 14: //-subnormal
	case 15:
		*p32=((*p32)&0x007fffff)|0x80000000;
                break;
	}
}

void printfloat(uint64_t*f, uint8_t vsew_i);
using namespace std;

int main(){
	srand(time(NULL));
	uint64_t hi1=(uint64_t)rand()<<32;
	uint64_t lo1=rand();
	uint64_t hi2=(uint64_t)rand()<<32;
	uint64_t lo2=rand();
	uint64_t hi3=(uint64_t)rand()<<32;
	uint64_t lo3=rand();

	uint64_t rnd1_i=hi1|lo1;
	uint64_t rnd2_i=hi2|lo2;
	uint64_t rnd3_i=hi3|lo3;

	uint64_t rnd4_i=rand();

	uint8_t vsew_i=2; //3=64bit | 2=32bit

	uint8_t op_group_i;
	uint8_t op_ctrl_i;
	uint8_t vxrm_i;
	uint8_t scenario_id_i;

	uint64_t out1;
	uint64_t out2;
	uint64_t out3;

	uint64_t src1_data_o;
	uint64_t src2_data_o;
	uint64_t src3_data_o;
	uint8_t	setcorner=1; //setcorner=0: single corner mode off | setcorner =/= 0: single corner mode on
        //setcorner=[1-3]: selected position in 64bit format, setcorner=[1:6]:selected position in 32bit format
	int i;
	int n=1000;
	ofstream hexfile;
	hexfile.open("../compare/data_in.hex");
	for(i=0;i<n;i++){
	        hi1=(uint64_t)rand()<<32;
	        lo1=rand();
	        hi2=(uint64_t)rand()<<32;
	        lo2=rand();
	        hi3=(uint64_t)rand()<<32;
	        lo3=rand();
	        rnd1_i=hi1|lo1;
	        rnd2_i=hi2|lo2;
	        rnd3_i=hi3|lo3;
        	rnd4_i=rand();

		sequence_corner_gen_fpu32_64(
		rnd1_i,
		rnd2_i,
		rnd3_i,
		rnd4_i,
		vsew_i,
		op_group_i,
		op_ctrl_i,
		vxrm_i,
		scenario_id_i,
		setcorner,
		src1_data_o,
		src2_data_o,
		src3_data_o
		);
		printfloat(&src1_data_o,vsew_i);
		printfloat(&src2_data_o,vsew_i);
		printfloat(&src3_data_o,vsew_i);
		cout << endl;
		hexfile << hex << setfill('0') << std::setw(16) << src1_data_o << endl;

//		hexfile << setfill('0') << std::setw(16) << 0 << endl; //uncomment these 2 lines to set other 2 operands to zero
//		hexfile << setfill('0') << std::setw(16) << 0 << endl;

		hexfile << setfill('0') << std::setw(16) << src2_data_o << endl; //and comment these to set other 2 operands to zero
		hexfile << setfill('0') << std::setw(16) << src3_data_o  << endl;
	}
	hexfile.close();
	return 0;
}

void printfloat(uint64_t*f, uint8_t vsew_i){
        int i,j;
        char*ps;
        ps=reinterpret_cast<char*>(f);
        if (vsew_i==3){ //print one 64-bit-FP
                for (i=7;i>=0;i--){
                        for (j=7;j>=0;j--){
                            cout << (((*reinterpret_cast<unsigned char*>(ps + i)) & (1 << j)) >> j);
                                if ( ((j==7) && (i==7)) || ((j==4) && (i==6)) ){
                                        cout << " ";
                                }
                        }
	        }
        } else { //print 64 bits as 2 distinct 32-bit-FPs
                for (i=7;i>=0;i--){
                        for (j=7;j>=0;j--){
                            cout << (((*reinterpret_cast<unsigned char*>(ps + i)) & (1 << j)) >> j);
                                if ( (j==7) && ((i==3) || (i==2) || (i==7) || (i==6))){
//                                if (j==4){
                                        cout << " ";
                                } else if ( (j==0) && (i==4) ) {
                                        cout << " | ";
                                }
                        }
//			printf(" %p\n",ps+i);
                }
        }
	cout << endl;
}
