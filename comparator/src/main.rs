use std::{env, io::{BufReader, prelude::*}, cell::{Ref, RefCell}};
use std::fs::File;
use std::process::exit;

use indicatif::{ProgressBar, ProgressStyle};

struct FileStat {
    file: BufReader<File>,
    name: String,
    zero: usize,
    blkd: usize,
    read: (Vec<u8>, usize),
}

impl FileStat {
    // read n bytes and update the buffer and size into self.read
    pub fn read_block(&mut self, bytes: usize) -> &mut Self {
        let mut buf = vec![];
        let mut chunk = self.file.get_mut().take(bytes as u64);
        let n = chunk.read_to_end(&mut buf).unwrap_or(0);

        self.read = (buf, n);

        self
    }

    // check the buffer and bump self.zero if all bytes in buffer is 0u8
    pub fn check_and_bump_zero(&mut self) -> &mut Self {
        if self.read.0.iter().all(|b| {
            *b == 0u8
        }) {
            self.zero += 1;
        }
        self
    }

    // check self.read.0 == other.read.0, if different bump self.blkd
    pub fn check_and_bump_diff(&mut self, other: Ref<Self>) -> &mut Self {
        for (a, b) in self.read.0.iter().zip(other.read.0.iter()) {
            if *a != *b {
                self.blkd += 1;
                return self;
            }
        };

        if self.read.1 != other.read.1 {
            self.blkd += 1;
        }
        self
    }
}

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() < 3 {
        eprintln!("Got arguments: {:?}", args);
        eprintln!("Usage: comparator BlockSize File [Files...]");
        eprintln!("Example: comparator 4 f1.bin");
        eprintln!("Example: comparator 4 f1.bin f2.bin f3.bin");
        exit(1);
    }

    // Test if compare is needed
    let compare_mode: bool = args.len() >= 4;

    // Retrieve block size
    let block_size: usize = args[1].trim()
                                   .parse::<usize>()
                                   .expect("Please provide a block size in byte");
    if block_size == 0 {
        panic!("block size cannot be 0");
    }

    // Initialize FileStat list, containing all files
    let mut files = Vec::with_capacity(args.len() - 2);
    for f in &args[2..] {
        files.push(
            RefCell::new(FileStat {
                file: BufReader::<File>::new(File::open(f.trim()).unwrap()),
                name: f.clone(),
                zero: 0usize,
                blkd: 0usize,
                read: (Vec::<u8>::new(), 0usize),
            })
        );
    }

    // Set total blocks and check sizes
    let total_blocks;
    if files.windows(2).all(|f| {
        f[0].borrow().file.get_ref().metadata().unwrap().len()
            == f[1].borrow().file.get_ref().metadata().unwrap().len()
    }) {
        total_blocks = (files[0].borrow().file.get_ref().metadata().unwrap().len() as f64 /
                        block_size as f64).ceil() as usize;
    } else {
        panic!("File sizes are different, cannot compare");
    }

    // Setup progress bar
    let progress = ProgressBar::new(total_blocks as u64);
    progress.set_style(ProgressStyle::default_bar()
                                     .template("[{elapsed}] {wide_bar} {pos}/{len} [{eta_precise}] {msg}"));

    // Start compare and record 0s
    for _ in 0..total_blocks {
        files.iter().for_each(|file| {
            file.borrow_mut()
                .read_block(block_size)
                .check_and_bump_zero();
        });

        if compare_mode {
            files.windows(2).for_each(|window| {
                window[0].borrow_mut()
                         .check_and_bump_diff(window[1].borrow());
            });
        }

        progress.inc(1);
    }

    progress.finish_and_clear();

    // Output results
    println!("fileName,zeros,diffBlocks");
    files.iter().for_each(|f| {
        println!("{},{},{}", f.borrow().name, f.borrow().zero, f.borrow().blkd);
    });
}
