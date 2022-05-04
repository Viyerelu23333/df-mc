use std::{env, io::{BufReader, prelude::*}};
use std::fs::File;
use std::process::exit;
use std::time::Instant;

use flate2::{Compression, write::GzEncoder};
use indicatif::{ProgressBar, HumanBytes, ProgressStyle};

fn read_nbytes<R: Read>(reader: R, bytes: usize) -> (Vec<u8>, usize) {
    let mut buf = vec![];
    let mut chunk = reader.take(bytes as u64);
    let n = chunk.read_to_end(&mut buf).unwrap_or(0);

    (buf, n)
}

fn main() {
    let args: Vec<String> = env::args().collect();

    if args.len() != 4 {
        eprintln!("Got arguments: {:?}", args);
        eprintln!("Usage: compressor CompLv BlkSize File");
        eprintln!("Example: compressor 6 4096 23.3333333333333.bin");
        exit(1);
    }

    // Parse the arguments
    let cmplv: u32 = args[1].trim().parse::<u32>()
                            .expect("Please provide a level [0..9]");

    let mut blksz: usize = args[2].trim().parse::<usize>()
                                  .expect("Please provide a block size in byte");

    // Open binary file with BufReader
    let fd = File::open(args[3].trim()).unwrap();
    if blksz == 0 {
        blksz = fd.metadata().unwrap().len() as usize;
    }

    let total_blocks = (fd.metadata().unwrap().len() as f32 / blksz as f32).ceil() as usize;
    let mut fbuf = BufReader::new(fd);

    // Statistics
    let mut total_bytes: usize = 0;
    let mut read_counter: usize = 1;
    let mut avg_time: u128 = 0;

    let progress = ProgressBar::new(total_blocks as u64);
    progress.set_style(ProgressStyle::default_bar()
                                     .template("[{elapsed}] {wide_bar} {pos}/{len} [{eta_precise}] {msg}"));

    // First read
    let (mut readbuf, mut byteread) = read_nbytes(&mut fbuf, blksz);

    while byteread != 0 {
        // initialize GZip encoder
        let mut gzip = GzEncoder::new(Vec::<u8>::with_capacity(blksz), Compression::new(cmplv));

        // write all readbuf to GZip buffer
        gzip.write_all(&mut readbuf).unwrap();

        // compress and get the length, time of the result
        let now = Instant::now();
        let compressed = gzip.finish().unwrap();
        avg_time += now.elapsed().as_nanos();
        total_bytes += compressed.len();

        progress.inc(1);
        read_counter += 1;

        // read next block
        (readbuf, byteread) = read_nbytes(&mut fbuf, blksz);
    }
    progress.finish_and_clear();
    eprintln!("Total blocks: {}, Compressed size: {}, Average time: {:.3}ns",
              total_blocks, HumanBytes(total_bytes as u64),
              avg_time as f64 / read_counter as f64);
    println!("{}", total_bytes);
}
