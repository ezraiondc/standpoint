extern crate graph_match;
use std::collections::HashMap;

pub fn parse(string: String) -> Result<graph_match::graph::Graph, String> {
    let mut graph = graph_match::graph::Graph {
        nodes: vec![],
        edges: vec![],
    };
    for line in string.split("\n") {
        let attributes = parse_line(line.to_string());
        match attributes.get("type") {
            Some(element_type) => {
                match element_type.as_str() {
                    "node" => {
                        match attributes.get("identifier") {
                            Some(identifier) => {
                                graph.add_node(identifier.clone(), Some(attributes.clone()));
                            }
                            None => return Err("Missing identifier".to_string()),
                        }
                    }
                    "edge" => {
                        match attributes.get("identifier") {
                            Some(identifier) => {
                                match extract_source_target(&attributes) {
                                    Some((source, target)) => {
                                        graph.add_edge(source,
                                                       target,
                                                       identifier.clone(),
                                                       Some(attributes.clone()));
                                    }
                                    None => return Err("Invalid source or target".to_string()),
                                }
                            }
                            None => return Err("Missing identifier".to_string()),
                        }
                    }
                    _ => return Err("Invalid type".to_string()),
                }
            }
            None => return Err("A line must have a graph component type".to_string()),
        }
    }
    return Ok(graph);
}

#[test]
fn parse_valid_graph() {
    let string_graph = "type:node identifier:node0\ntype:node identifier:node1\ntype:edge \
                        identifier:edge1 source:0 target:1";
    let graph = parse(string_graph.to_string());
    assert_eq!(true, graph.is_ok());
}
#[test]
fn parse_invalid_graph() {
    let string_graph = "type:thing identifier:node0\ntype:eddge identifier:edge1 source:0 target:1";
    let graph = parse(string_graph.to_string());
    assert_eq!(false, graph.is_ok());
}

fn parse_line(line: String) -> HashMap<String, String> {
    let mut attributes: HashMap<String, String> = HashMap::new();
    for pair in line.split(" ") {
        let mut pair = pair.split(":");
        match pair.next() {
            Some(k) => {
                if k.len() == 0 {
                    continue;
                }
                match pair.next() {
                    Some(v) => {
                        if v.len() == 0 {
                            continue;
                        }
                        attributes.insert(k.to_string(), v.to_string());
                    }
                    None => continue,
                }
            }
            None => continue,
        }
    }
    return attributes;
}

#[test]
fn parse_line_to_attributes() {
    let line = "type:node key:value".to_string();
    let attributes = parse_line(line);
    let mut expected_attributes: HashMap<String, String> = HashMap::new();
    expected_attributes.insert("type".to_string(), "node".to_string());
    expected_attributes.insert("key".to_string(), "value".to_string());
    assert_eq!(expected_attributes.len(), attributes.len());
    for pair in &expected_attributes {
        assert_eq!(attributes.get(pair.0).unwrap(), pair.1);
    }
}
#[test]
fn parse_line_to_attributes_poorly_formatted() {
    let line = "type:node key:value key2 : value ".to_string();
    let attributes = parse_line(line);
    let mut expected_attributes: HashMap<String, String> = HashMap::new();
    expected_attributes.insert("type".to_string(), "node".to_string());
    expected_attributes.insert("key".to_string(), "value".to_string());
    assert_eq!(expected_attributes.len(), attributes.len());
    for pair in &expected_attributes {
        assert_eq!(attributes.get(pair.0).unwrap(), pair.1);
    }
}

fn extract_source_target(attributes: &HashMap<String, String>) -> Option<(usize, usize)> {
    match attributes.get("source") {
        Some(source) => {
            match attributes.get("target") {
                Some(target) => {
                    let usize_source = source.parse::<usize>();
                    let usize_target = target.parse::<usize>();
                    if usize_source.is_ok() && usize_target.is_ok() {
                        return Some((usize_source.unwrap(), usize_target.unwrap()));
                    } else {
                        return None;
                    }
                }
                None => return None,
            }
        }
        None => return None,
    }
}

#[test]
fn extract_source_and_target_from_attributes() {
    let mut attributes: HashMap<String, String> = HashMap::new();
    attributes.insert("source".to_string(), "1".to_string());
    attributes.insert("target".to_string(), "2".to_string());
    assert_eq!(Some((1, 2)), extract_source_target(&attributes));
}
#[test]
fn extract_source_and_target_from_attributes_invalid() {
    let mut attributes: HashMap<String, String> = HashMap::new();
    attributes.insert("source".to_string(), "a".to_string());
    attributes.insert("target".to_string(), "b".to_string());
    assert_eq!(None, extract_source_target(&attributes));
}
#[test]
fn extract_source_and_target_from_attributes_missing() {
    let mut attributes: HashMap<String, String> = HashMap::new();
    attributes.insert("key".to_string(), "value".to_string());
    assert_eq!(None, extract_source_target(&attributes));
}
