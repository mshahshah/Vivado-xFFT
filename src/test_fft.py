import os, sys
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.colors as mcolors

CP_table = {1024:[1096, 1160],
            512: [550, 560]}

K = 10*12 # number of OFDM RBs
CP = K//4  # length of the cyclic prefix: 25% of the block
P = 6 # number of pilot carriers per OFDM block
pilotValue = 3+3j # The known value each pilot transmits
mu = 4  # bits per symbol (i.e. 16QAM)


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



def plot_input_signal(time_signal, freq_signal, freq_signal_shifted, cfg):
    x_space = range(len(time_signal))
    fig, ax = plt.subplots(3, 2, figsize=(18, 15))
    ax[0,0].plot(np.imag(time_signal),  label='Time.Imag', color='cyan')
    ax[0,0].set_xlabel('Time (sec)')
    ax[0,0].set_ylabel('Amplitude')

    ax[0,1].plot(np.real(time_signal),  label='Time.Real', color='blue')
    ax[0,1].set_xlabel('Time (sec)')


    ax[1,0].plot(np.imag(freq_signal),  label='Freq.Imag', color='gold')
    ax[1,0].set_xlabel('Freq')
    ax[1,0].set_ylabel('Amplitude')

    ax[1,1].plot(np.real(freq_signal),  label='Freq.Real', color='orange')
    ax[1,1].set_xlabel('Freq')

    ax[2,0].plot(np.imag(freq_signal_shifted),  label='Time.imag', color='green')
    ax[2,0].set_xlabel('Freq')
    ax[2,0].set_ylabel('Amplitude')
    ax[2,1].plot(np.real(freq_signal_shifted),  label='Time.Real', color='limegreen')
    ax[2,1].set_xlabel('Freq')

    #ax[3,0].plot(x_space, np.imag(err),  label='Err.Imag', color='tomato')
    #ax[3,0].set_xlabel('Freq')
    #ax[3,0].set_ylabel('Amplitude mismatch')
    #ax[3,1].plot(x_space, np.real(err),  label='Err.Real', color='red')
    #ax[3,1].set_xlabel('Freq')

    fig.legend()
    plt.savefig(os.path.join('stimulus_files','SW_{}S.jpg'.format(cfg['FFT_size'])), dpi=200)
    return

def save_IQvector_as(vector, fname, formats=['csv','txt']):
    for fmt in formats:
        final_fname = os.path.join('stimulus_files', fname + '.' + fmt)
        flines = []
        for i in vector:
            flines.append('{},{}'.format(i.imag.astype(int), i.real.astype(int)))
        save_list_to_file(final_fname, flines)


def plot_constulation():
    for b3 in [0, 1]:
        for b2 in [0, 1]:
            for b1 in [0, 1]:
                for b0 in [0, 1]:
                    B = (b3, b2, b1, b0)
                    Q = mapping_table[B]*1000
                    plt.plot(Q.imag, Q.real, 'bo')
                    plt.text(Q.imag, Q.real + 0.2, "".join(str(x) for x in B), ha='center')
                    plt.grid(True)
    plt.show()

def OFDM_symbol(QAM_payload):
    symbol = np.zeros(K, dtype=complex)  # the overall K subcarriers
    symbol[pilotCarriers] = pilotValue  # allocate the pilot subcarriers
    symbol[dataCarriers] = QAM_payload  # allocate the pilot subcarriers
    return symbol


def generate_ofdm_signal(amp=1000, cfg={}):
    payloadBits_per_OFDM = len(dataCarriers) * mu
    bits = np.random.binomial(n=1, p=0.5, size=(payloadBits_per_OFDM,))
    bits_SP = bits.reshape((len(dataCarriers), mu))
    QAM = np.array([mapping_table[tuple(b)] for b in bits_SP])  # mapping
    OFDM_signal = (OFDM_symbol(QAM) * amp / 3).round()
    pad_size = int((cfg['FFT_size'] - OFDM_signal.shape[0]) / 2)
    OFDM_freq = np.concatenate((np.zeros(pad_size), OFDM_signal, np.zeros(pad_size)), axis=0)
    OFDM_time = np.fft.ifft(OFDM_freq, cfg['FFT_size'])
    OFDM_time_shift = np.fft.ifftshift(OFDM_freq)
    return OFDM_time, OFDM_freq, OFDM_time_shift

def generate_impulse_response_signal():
    channelResponse = np.array([1, 0, 0.3 + 0.3j])
    H_exact = np.fft.fft(channelResponse, K)
    plt.plot(allCarriers, abs(H_exact))
    return H_exact

def create_tcl_cfg_for_project(cfg):
    cfg_lines = []
    cfg_lines.append('# This is a auto-generated file from python!')
    cfg_lines.append('set ip_cfg_mode new')
    cfg_lines.append('set prj_name {}'.format(cfg['prj_name']))
    cfg_lines.append('set module_name "ifft_ss0"')
    cfg_lines.append('set nSymbols {}'.format(cfg['nSymbols']))
    cfg_lines.append('set fft_clk  {}'.format(cfg['clk_period']))
    cfg_lines.append('set fft_size {}'.format(cfg['FFT_size']))
    cfg_lines.append('set rounding {}'.format(cfg['rounding']))
    save_list_to_file(os.path.join('src','build_fft_cfg.tcl'),cfg_lines)

def create_fft_project(cfg):
    print("Started building a FFT project, reports are in : FFT_block_design.log")
    os.system('vivado -notrace -mode batch -source src/fft_build.tcl > FFT_block_design.log')

def run_vivado_sim(cfg, sim_type='sim'):
    print("Started running sim, reports are in : FFT_sim.log")
    os.system('vivado -notrace -mode batch -source src/fft_sim.tcl -tclargs {} > FFT_sim.log'.format(sim_type))

def compare_SW_vs_HW(cfg, sw_output):
    filename = os.path.join('stimulus_files', 'hw_xfft_output_C1')
    hw_output_str = load_csv_to_list(filename)
    hw_output = []
    for line in hw_output_str:
        hw_output.append(complex(int(line.split(',')[0]), int(line.split(',')[1])))

    mismatch = np.array(hw_output) - sw_output
    x_space = len(hw_output)
    fig, ax = plt.subplots(3, 2, figsize=(14, 10))
    ax[0,0].plot(np.imag(sw_output),  label='Time.Imag', color='cyan', linestyle='-')
    ax[0,0].set_xlabel('Time (sec)')
    ax[0,0].set_ylabel('sw_output')
    ax[0,1].plot(np.real(sw_output),  label='Time.Real', color='blue', linestyle='-')
    ax[0,1].set_xlabel('Time (sec)')

    ax[1,0].plot(np.imag(hw_output),  label='Time.Imag', color='gold', linestyle='-')
    ax[1,0].set_xlabel('Time (sec)')
    ax[1,0].set_ylabel('hw_output')
    ax[1,1].plot(np.real(hw_output),  label='Time.Real', color='orange', linestyle='-')
    ax[1,1].set_xlabel('Time (sec)')

    ax[2,0].plot(np.imag(mismatch),  label='Time.Imag', color='green')
    ax[2,0].set_xlabel('Time (sec)')
    ax[2,0].set_ylabel('mismatch')
    ax[2,1].plot(np.real(mismatch),  label='Time.Real', color='limegreen')
    ax[2,1].set_xlabel('Time (sec)')

    fig.legend()
    plt.savefig(os.path.join('stimulus_files','HW_{}S.jpg'.format(cfg['FFT_size'])), dpi=200)

##############################################################################
###########################   MAIN   #########################################
##############################################################################

if __name__ == '__main__':

    print("Started Testing the FFT module")

    fft_cfg={
        'prj_name': 'fft_prj_cp',
        'FFT_size': 1024,
        'clk_period': 122.88,
        'insert_cp': True,
        'direction':'f2t',  # 'f2t', 't2f
        'rounding':'round',  # round / trunc
        'nSymbols': 4
    }

    vivado_prj = True
    sim_type = 'sim' # sim, resim, none

    os.chdir(os.path.split(os.getcwd())[0])
    #sin_wave = generate_1D_sin_wave(N=FFT_size, T=10.0/800.0)
    print("Generating Stimulus test-data")

    if fft_cfg['direction'] == 't2f':
        sw_time_signal, sw_freq_signal, sw_freq_signal_shifted = generate_complex_sin_wave(amp=[1000, 500], freq=[3, 30], cfg=fft_cfg, cycles=1)
        plot_input_signal(sw_time_signal, sw_freq_signal, sw_freq_signal_shifted, fft_cfg)
        save_IQvector_as(sw_time_signal, fname='xFFT_input', formats=['csv'])
        save_IQvector_as(sw_freq_signal, fname='sw_xfft_output_C1', formats=['csv'])
    else:
        sw_time_signal, sw_freq_signal, OFDM_time_shift = generate_ofdm_signal(amp=1000, cfg=fft_cfg)
        plot_input_signal(sw_time_signal, sw_freq_signal, OFDM_time_shift, fft_cfg)
        save_IQvector_as(sw_freq_signal, fname='xFFT_input_1024_10RB', formats=['csv'])
        save_IQvector_as(sw_time_signal, fname='sw_xfft_output_C1', formats=['csv'])

    print("Stimulus signal is generated !")

    create_tcl_cfg_for_project(fft_cfg)
    if vivado_prj:
        create_fft_project(fft_cfg)
    if sim_type is not 'none' :
        run_vivado_sim(fft_cfg, sim_type=sim_type)

    if fft_cfg['direction'] == 't2f':
        compare_SW_vs_HW(fft_cfg, sw_freq_signal)
    else:
        compare_SW_vs_HW(fft_cfg, sw_time_signal)


    #OFDM_data, OFDM_time = generate_ofdm_signal()

    #print(sin_wave)
