import os, sys
import numpy as np
import matplotlib.pyplot as plt
from scipy import signal

import matplotlib.colors as mcolors
dir_path = os.path.dirname(os.path.realpath(__file__))
os.chdir(dir_path)

CP_table = {1024:[1096, 1160],
            512: [550, 560]}


TotalRB = 20       # number of OFDM RBs
K = TotalRB*12
CP = K//4          # length of the cyclic prefix: 25% of the block
P = 6              # number of pilot carriers per OFDM block
pilotValue = 3+3j  # The known value each pilot transmits
mu = 4             # bits per symbol (i.e. 16QAM)


allCarriers = np.arange(K)  # indices of all subcarriers ([0, 1, ... K-1])
pilotCarriers = allCarriers[::K//P] # Pilots is every (K/P)th carrier.
dataCarriers = np.delete(allCarriers, pilotCarriers)

mapping_table = {
    (0, 0, 0, 0): -3 - 3j,
    (0, 0, 0, 1): -3 - 1j,
    (0, 0, 1, 0): -3 + 3j,
    (0, 0, 1, 1): -3 + 1j,
    (0, 1, 0, 0): -1 - 3j,
    (0, 1, 0, 1): -1 - 1j,
    (0, 1, 1, 0): -1 + 3j,
    (0, 1, 1, 1): -1 + 1j,
    (1, 0, 0, 0): 3 - 3j,
    (1, 0, 0, 1): 3 - 1j,
    (1, 0, 1, 0): 3 + 3j,
    (1, 0, 1, 1): 3 + 1j,
    (1, 1, 0, 0): 1 - 3j,
    (1, 1, 0, 1): 1 - 1j,
    (1, 1, 1, 0): 1 + 3j,
    (1, 1, 1, 1): 1 + 1j
}

def create_directory(path, directoryName):
    sol_copy_name = os.path.join(path ,directoryName)
    if not os.path.exists(sol_copy_name):
        os.makedirs(sol_copy_name)

def save_list_to_file(filename, data):
    try:
        with open(filename, 'w') as f:
            for line in data:
                f.write("%s\n" % line)
    except:
        print("Can not open file: {}".format(filename))

def load_csv_to_list(filename):
    with open('{}.csv'.format(filename), 'r') as f:
        results = []
        for line in f:
            words = line.split(',')
            results.append(line)
    return results



def generate_1D_sin_wave(N, T):
    # N = Number of sample points
    # T = sample spacing
    x = np.linspace(0.0, N * T, N, endpoint=False)
    y = np.sin(50.0 * 2.0 * np.pi * x) + 0.5 * np.sin(80.0 * 2.0 * np.pi * x)
    return y

def generate_complex_sin_wave(freq=[2], amp=[100], phi=0, cfg={}, cycles=3):
    time_signal = 0

    t = np.linspace(0, np.pi, cfg['FFT_size']).repeat(cycles)
    total_samples = cycles * cfg['FFT_size']
    for sig in range(len(freq)):
        k1 = 2 * np.pi * freq[sig] * t + phi
        cwv_t = amp[sig] * np.exp(-1j* k1) # complex sine wave
        time_signal = time_signal + cwv_t
    time_signal = time_signal.round()
    freq_signal = np.fft.fft(time_signal, cfg['FFT_size']).round()

    freq_signal_shifted = np.fft.fftshift(freq_signal, cfg['FFT_size']).round()

    time_signal2 = np.fft.ifft(freq_signal, cfg['FFT_size']).round()
    err = time_signal - time_signal2
    return time_signal, freq_signal, freq_signal_shifted



def plot_input_signal(time_signal, freq_signal, freq_signal_shifted, cfg, label=''):
    x_space = range(len(time_signal))
    fig, ax = plt.subplots(3, 2, figsize=(18, 15))
    ax[0,0].plot(np.real(time_signal),  label='Time.Real', color='cyan')
    ax[0,0].set_xlabel('Time (sec)')
    ax[0,0].set_ylabel('Amplitude')

    ax[0,1].plot(np.imag(time_signal),  label='Time.Imag', color='blue')
    ax[0,1].set_xlabel('Time (sec)')


    ax[1,0].plot(np.real(freq_signal),  label='Freq.Real', color='gold')
    ax[1,0].set_xlabel('Freq')
    ax[1,0].set_ylabel('Amplitude')

    ax[1,1].plot(np.imag(freq_signal),  label='Freq.Imag', color='orange')
    ax[1,1].set_xlabel('Freq')

    ax[2,0].plot(np.real(freq_signal_shifted),  label='Time.Real', color='green')
    ax[2,0].set_xlabel('Freq')
    ax[2,0].set_ylabel('Amplitude')
    ax[2,1].plot(np.imag(freq_signal_shifted),  label='Time.Imag', color='limegreen')
    ax[2,1].set_xlabel('Freq')

    fig.legend()
    plt.savefig(os.path.join('stimulus_files','SW_{}S.jpg'.format(cfg['FFT_size'])), dpi=200)
    return

def save_IQvector_as(vector, fname, formats=['csv','txt']):
    for fmt in formats:
        final_fname = os.path.join('stimulus_files', fname + '.' + fmt)
        flines = []
        for i in vector:
            flines.append('{},{}'.format(i.real.astype(int), i.imag.astype(int)))  # [Real Imag]
        save_list_to_file(final_fname, flines)


def plot_constulation():
    for b3 in [0, 1]:
        for b2 in [0, 1]:
            for b1 in [0, 1]:
                for b0 in [0, 1]:
                    B = (b3, b2, b1, b0)
                    Q = mapping_table[B]*1000
                    plt.plot(Q.real, Q.imag, 'bo')
                    plt.text(Q.real, Q.imag, + 0.2, "".join(str(x) for x in B), ha='center')
                    plt.grid(True)
    plt.show()

def OFDM_symbol(QAM_payload):
    symbol = np.zeros(K, dtype=complex)  # the overall K subcarriers
    symbol[pilotCarriers] = pilotValue  # allocate the pilot subcarriers
    symbol[dataCarriers] = QAM_payload  # allocate the pilot subcarriers
    return symbol


def generate_ofdm_signal(amp=1000):
    payloadBits_per_OFDM = len(dataCarriers) * mu
    bits = np.random.binomial(n=1, p=0.5, size=(payloadBits_per_OFDM,))
    bits_SP = bits.reshape((len(dataCarriers), mu))
    QAM = np.array([mapping_table[tuple(b)] for b in bits_SP])  # mapping
    OFDM_freq = (OFDM_symbol(QAM) * amp / 3).round()
    return OFDM_freq

def pad_zero(cfg, OFDM_freq):
    pad_size = int((cfg['FFT_size'] - OFDM_freq.shape[0]) / 2)
    OFDM_freq_pad = np.concatenate((np.zeros(pad_size), OFDM_freq, np.zeros(pad_size)), axis=0)
    return OFDM_freq_pad


def resample(cfg, in_signal, rate):
    resample_rate = in_signal.shape[0] * rate
    resampled_sig = signal.resample(in_signal,resample_rate).round()
    repeated_sig = np.repeat(in_signal, rate)

    fig, ax = plt.subplots(3, 2, figsize=(14, 10))
    ax[0,0].plot(np.real(in_signal),  label='in_signal.Real', color='blue', linestyle='-')
    ax[0,0].set_ylabel('in_signal')
    ax[0,1].plot(np.imag(in_signal),  label='in_signal.Imag', color='blue', linestyle='-')

    ax[1,0].plot(np.real(resampled_sig),  label='resampled_sig.Real', color='orange', linestyle='-')
    ax[1,0].set_ylabel('resampled_sig')
    ax[1,1].plot(np.imag(resampled_sig),  label='resampled_sig.Imag', color='orange', linestyle='-')

    ax[2,0].plot(np.real(repeated_sig),  label='repeated_sig.Real', color='red', linestyle='-')
    ax[2,0].set_ylabel('repeated_sig')
    ax[2,1].plot(np.imag(repeated_sig),  label='repeated_sig.Imag', color='red', linestyle='-')

    return resampled_sig, repeated_sig


def generate_impulse_response_signal():
    channelResponse = np.array([1, 0, 0.3 + 0.3j])
    H_exact = np.fft.fft(channelResponse, K)
    plt.plot(allCarriers, abs(H_exact))
    return H_exact

def create_tcl_cfg_for_project(cfg, run_syn):
    cfg_lines = []
    cfg_lines.append('# This is a auto-generated file from python!')
    cfg_lines.append('set ip_cfg_mode new')
    cfg_lines.append('set prj_name {}'.format(cfg['prj_name']))
    cfg_lines.append('set module_name "ifft_cc0"')
    cfg_lines.append('set nSymbols {}'.format(cfg['nSymbols']))
    cfg_lines.append('set fft_clk  {}'.format(cfg['clk_period']))
    cfg_lines.append('set fft_size {}'.format(cfg['FFT_size']))
    cfg_lines.append('set rounding {}'.format(cfg['rounding']))
    cfg_lines.append('set STAGE_BRAM {}'.format(cfg['STAGE_BRAM']))
    if run_syn:
        cfg_lines.append('set run_syn true')
    else:
        cfg_lines.append('set run_syn false')
    save_list_to_file(os.path.join('src','build_fft_cfg.tcl'),cfg_lines)

def create_fft_project(cfg):
    print("Started building a FFT project, reports are in : FFT_block_design.log")
    os.system('/tools/apps/xilinx/2020.2/Vivado/2020.2/bin/vivado -notrace -mode batch -source src/fft_build.tcl > FFT_block_design.log')

def run_xFFT_DSE(cfg):
    print("Started DSE FFT project:")
    STAGE_BRAM_table = {256:[1,2], 512:[2,3], 1024:[2,3,4], 2048:[3,4,5], 4096:[3,4,5,6]}
    for FFT_size in [256, 512, 1024, 2048, 4096]:
        for STAGE in STAGE_BRAM_table[FFT_size]:
            rpt_file = 'FFT_bd_{}_{}.log'.format(FFT_size, STAGE)
            cfg['STAGE_BRAM'] = STAGE
            cfg['FFT_size'] = FFT_size
            cfg['prj_name'] = 'fft_prj_{}_{}'.format(FFT_size, STAGE)
            print("\t Building FFT {} for Stage {} : reports are in : {}".format(FFT_size, STAGE, rpt_file))
            create_tcl_cfg_for_project(cfg, run_syn)
            os.system('/tools/apps/xilinx/2020.2/Vivado/2020.2/bin/vivado -notrace -mode batch -source src/fft_build.tcl > {}'.format(rpt_file))

def run_vivado_sim(cfg):
    print("Started running sim, reports are in : FFT_sim.log")
    os.system('vivado -notrace -mode batch -source sim/fft_sim.tcl -tclargs {} > {} '.format('sim', 'FFT_sim.log'))

def compare_SW_vs_HW(cfg, sw_file, hw_file):
    sig_from = 1
    sig_to = -1
    filename = os.path.join('stimulus_files', hw_file)
    hw_output_str = load_csv_to_list(filename)
    hw_output = []
    for line in hw_output_str[:-2]:
        hw_output.append(complex(int(line.split(',')[0]), int(line.split(',')[1])))
    hw_output_masked = []
    for i in hw_output:
        if i != 0:
            hw_output_masked.append(i)
    hw_output_masked=np.array(hw_output_masked)
    filename = os.path.join('stimulus_files', sw_file)
    sw_output_str = load_csv_to_list(filename)
    sw_output = []
    for line in sw_output_str:
        sw_output.append(complex(int(line.split(',')[0]), int(line.split(',')[1])))
    
    sw_output = np.array(sw_output[sig_from:sig_to])
    hw_output_trimed = np.array(hw_output_masked[sig_from:sig_to])

    #sw_output = sw_output/abs(sw_output).max()
    #hw_output_trimed = hw_output_trimed/abs(hw_output_trimed).max()
    mismatch = (hw_output_trimed - sw_output)
    MAE = np.abs(mismatch).mean()
    print("The Mean Ablsolute Error is: {}".format(MAE))
    if MAE < 10:
        print("Verification is Passed !")
    #corr=signal.correlate(hw_output_trimed, sw_output)
    #corr /= np.max(corr)
    
    #plt.plot(corr)
    #plt.show()
    fig, ax = plt.subplots(3, 2, figsize=(14, 10))
    for rr in range(2):
        for cc in range(2):
            ax[rr,cc].set_ylim(-2**15,2**15)
    ax[0,0].plot(np.real(sw_output),  label='SW.Real', color='blue', linestyle='-')
    ax[0,0].set_ylabel('sw_output')
    ax[0,1].plot(np.imag(sw_output),  label='SW.Imag', color='blue', linestyle='-')

    ax[1,0].plot(np.real(hw_output_trimed),  label='HW.Real', color='orange', linestyle='-')
    ax[1,0].set_ylabel('hw_output')
    ax[1,1].plot(np.imag(hw_output_trimed),  label='HW.Imag', color='orange', linestyle='-')

    ax[2,0].plot(np.real(mismatch),  label='Error.Real', color='red')
    ax[2,0].set_ylabel('mismatch MAE={:<3.3f}'.format(MAE))
    ax[2,1].plot(np.imag(mismatch),  label='Error.Imag', color='red')


    fig.legend()
    plt.savefig(os.path.join('stimulus_files','HW_{}S.jpg'.format(cfg['FFT_size'])), dpi=200)


def take_fft_of_a_file(cfg, OFDM_freq):
    OFDM_time = (np.fft.ifft(OFDM_freq, cfg['FFT_size']) * cfg['FFT_size'] / 2).round()
    OFDM_time_shift = (np.fft.ifftshift(OFDM_freq) * cfg['FFT_size'] / 2 ).round()
    return OFDM_time, OFDM_time_shift

def load_iq_from_csv_file(cfg, filename):
    output_str = load_csv_to_list(filename)
    sig_output = []
    for line in output_str:
        sig_output.append(complex(int(line.split(',')[0]), int(line.split(',')[1])))  # [Real Image]
    sig_output = np.array(sig_output)
    pad_size = int((cfg['FFT_size'] - sig_output.shape[0]) / 2)
    sig_output_pad = np.concatenate((np.zeros(pad_size), sig_output, np.zeros(pad_size)), axis=0)
    return sig_output_pad, sig_output

def add_cp(cfg, time_signal):
    cpLen = round(72*cfg['FFT_size']/1024)
    time_signal_cp = np.concatenate([time_signal[-cpLen:], time_signal])
    return time_signal_cp
##############################################################################
###########################   MAIN   #########################################
##############################################################################

if __name__ == '__main__':

    print("Started Testing the FFT module")

    fft_cfg={
        'prj_name': 'xFFT_4096',
        'FFT_size': 4096,
        'clk_period': 245,
        'insert_cp': True,
        'direction':'f2t',  # 'f2t', 't2f
        'rounding':'round',  # round / trunc
        'nSymbols': 1,
        'STAGE_BRAM': 3
    }

    DSE = False          # Create a prj for each setting in the dse function
    vivado_prj = True    # Create a project based on above fft_cfg
    run_syn = False      # Execute synthesize after creating a project
    run_sim = True       # sim, resim, none
    gen_new_data = True

    #sin_wave = generate_1D_sin_wave(N=FFT_size, T=10.0/800.0)
    print("Generating Stimulus test-data")

    if fft_cfg['direction'] == 't2f' and gen_new_data:
        sw_time_signal, sw_freq_signal, sw_freq_signal_shifted = generate_complex_sin_wave(amp=[1000, 500], freq=[3, 30], cfg=fft_cfg, cycles=1)
        plot_input_signal(sw_time_signal, sw_freq_signal, sw_freq_signal_shifted, fft_cfg, label='org_')
        save_IQvector_as(sw_time_signal, fname='xFFT_input', formats=['csv'])
        save_IQvector_as(sw_freq_signal, fname='sw_xfft_output_C1', formats=['csv'])
    else:
        if gen_new_data:
            OFDM_freq = generate_ofdm_signal(amp=2**10)
        else:
            OFDM_freq = load_iq_from_csv_file(fft_cfg, os.path.join('stimulus_files','xFFT_input'))

        resampled_OFDM_freq, repeated_OFDM_freq = resample(fft_cfg, OFDM_freq, 2)

        OFDM_freq_pad = pad_zero(fft_cfg, OFDM_freq)
        sw_time_signal, OFDM_time_shift = take_fft_of_a_file(fft_cfg, OFDM_freq_pad)
        sw_time_signal_cp = add_cp(fft_cfg, sw_time_signal)
        plot_input_signal(sw_time_signal, OFDM_freq_pad, OFDM_time_shift, fft_cfg, label='org_')
        save_IQvector_as(OFDM_freq, fname='xFFT_input')
        save_IQvector_as(OFDM_freq_pad, fname='xFFT_input_padded', formats=['csv'])
        save_IQvector_as(sw_time_signal, fname='sw_xFFT_output', formats=['csv'])
        save_IQvector_as(sw_time_signal_cp, fname='sw_xFFT_output_cp', formats=['csv'])

        OFDM_freq_pad = pad_zero(fft_cfg, resampled_OFDM_freq)
        sw_time_signal, OFDM_time_shift = take_fft_of_a_file(fft_cfg, OFDM_freq_pad)
        sw_time_signal_cp = add_cp(fft_cfg, sw_time_signal)
        plot_input_signal(sw_time_signal, OFDM_freq_pad, OFDM_time_shift, fft_cfg, label='res_')
        save_IQvector_as(resampled_OFDM_freq, fname='res_xFFT_input')
        save_IQvector_as(OFDM_freq_pad, fname='res_xFFT_input_padded', formats=['csv'])
        save_IQvector_as(sw_time_signal, fname='res_sw_xFFT_output', formats=['csv'])
        save_IQvector_as(sw_time_signal_cp, fname='res_sw_xFFT_output_cp', formats=['csv'])

        OFDM_freq_pad = pad_zero(fft_cfg, repeated_OFDM_freq)
        sw_time_signal, OFDM_time_shift = take_fft_of_a_file(fft_cfg, OFDM_freq_pad)
        sw_time_signal_cp = add_cp(fft_cfg, sw_time_signal)
        plot_input_signal(sw_time_signal, OFDM_freq_pad, OFDM_time_shift, fft_cfg, label='rep_')
        save_IQvector_as(repeated_OFDM_freq, fname='rep_xFFT_input')
        save_IQvector_as(OFDM_freq_pad, fname='rep_xFFT_input_padded', formats=['csv'])
        save_IQvector_as(sw_time_signal, fname='rep_sw_xFFT_output', formats=['csv'])
        save_IQvector_as(sw_time_signal_cp, fname='rep_sw_xFFT_output_cp', formats=['csv'])


    print("Stimulus signal is generated !")

    if DSE:
        run_xFFT_DSE(fft_cfg)
    else:
        create_tcl_cfg_for_project(fft_cfg, run_syn)
        if vivado_prj:
            create_fft_project(fft_cfg)
        if run_sim:
            run_vivado_sim(fft_cfg)

        if fft_cfg['direction'] == 't2f':
            compare_SW_vs_HW(fft_cfg, sw_file='sw_xFFT_output_cp', hw_file='hw_xfft_output_C0')
        else:
            compare_SW_vs_HW(fft_cfg, sw_file='sw_xFFT_output_cp', hw_file='hw_xfft_output_C0')


    #OFDM_data, OFDM_time = generate_ofdm_signal()

    #print(sin_wave)
