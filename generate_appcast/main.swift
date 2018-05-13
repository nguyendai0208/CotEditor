//
//  main.swift
//  Appcast
//
//  Created by Kornel on 20/12/2016.
//  Copyright © 2016 Sparkle Project. All rights reserved.
//

import Foundation

var verbose = false;

func printUsage() {
    let command = URL(fileURLWithPath: CommandLine.arguments.first!).lastPathComponent;
    print("Generate appcast from a directory of Sparkle updates\n",
        "Usage: \(command) < -f private key path | -k keychain_path -n key_name > <directory with update archives>\n",
        " e.g. \(command) -f dsa_priv.pem archives/\n",
        " Appcast files and deltas will be written to the archives directory.\n",
        " Note that pkg-based updates are not supported.\n"
    )
}

func main() {
    let args = CommandLine.arguments;
    if args.count < 4 {
        printUsage()
        exit(1)
    }
    
    let firstOption = args[1]
    let privateKey: SecKey
    
    if firstOption == "-f" && args.count == 4 {
        // private key specified by filename
        let privateKeyURL = URL(fileURLWithPath: args[2])
        
        do {
            privateKey = try loadPrivateKey(at: privateKeyURL)
        } catch {
            print("Unable to load DSA private key from", privateKeyURL.path, "\n", error)
            exit(1)
        }
    }
    else if (firstOption == "-n" || firstOption == "-k") && args.count == 6 {
        // private key specified by keychain + key name
        let keyName: String
        let keychainURL: URL
        
        if firstOption == "-n" {
            if args[3] != "-k" {
                printUsage()
                exit(1)
            }
            
            keyName = args[2]
            keychainURL = URL(fileURLWithPath: args[4])
        }
        else {
            if args[3] != "-n" {
                printUsage()
                exit(1)
            }
            
            keyName = args[4]
            keychainURL = URL(fileURLWithPath: args[2])
        }

        do {
            privateKey = try loadPrivateKey(named: keyName, fromKeychainAt: keychainURL)
        } catch {
            print("Unable to load DSA private key '\(keyName)' from keychain at", keychainURL.path, "\n", error)
            exit(1)
        }
    }
    else {
        printUsage()
        exit(1)
    }
    
    let archivesSourceDir = URL(fileURLWithPath: args.last!, isDirectory: true)

    do {
        let allUpdates = try makeAppcast(archivesSourceDir: archivesSourceDir, privateKey: privateKey, verbose:verbose);
        
        for (appcastFile, updates) in allUpdates {
            let appcastDestPath = URL(fileURLWithPath: appcastFile, relativeTo: archivesSourceDir);
            try writeAppcast(appcastDestPath:appcastDestPath, updates:updates);
            print("Written", appcastDestPath.path, "based on", updates.count, "updates");
        }
    } catch {
        print("Error generating appcast from directory", archivesSourceDir.path, "\n", error);
        exit(1);
    }
}

DispatchQueue.global().async(execute: {
    main();
    CFRunLoopStop(CFRunLoopGetMain());
});

CFRunLoopRun();
