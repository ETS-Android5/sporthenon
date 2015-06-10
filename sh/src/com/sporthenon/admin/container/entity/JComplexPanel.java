package com.sporthenon.admin.container.entity;

import javax.swing.JLabel;
import javax.swing.JTextField;

import com.sporthenon.admin.component.JCustomTextField;
import com.sporthenon.admin.component.JEntityPicklist;
import com.sporthenon.db.entity.City;
import com.sporthenon.utils.SwingUtils;


public class JComplexPanel extends JAbstractEntityPanel {
	
	private static final long serialVersionUID = 1L;
	
	public JCustomTextField jLabel;
	public JTextField jLabelFR;
	public JEntityPicklist jCity;

	public JComplexPanel() {
		super(4);
		initialize();
	}

	protected void initialize() {
        //Name
        JLabel lLabel = new JLabel(" Name:");
        lLabel.setHorizontalAlignment(LABEL_ALIGNMENT);
        gridPanel.add(lLabel);
        jLabel = new JCustomTextField();
        jLabel.setPreferredSize(TEXT_SIZE);
        gridPanel.add(jLabel);
        
        //Name (FR)
        JLabel lLabelFR = new JLabel(" Name (FR):");
        lLabelFR.setHorizontalAlignment(LABEL_ALIGNMENT);
        gridPanel.add(lLabelFR);
        jLabelFR = new JTextField();
        jLabelFR.setPreferredSize(TEXT_SIZE);
        gridPanel.add(jLabelFR);

        //City
        JLabel lCity = new JLabel(" City:");
        lCity.setHorizontalAlignment(LABEL_ALIGNMENT);
        gridPanel.add(lCity);
        jCity = new JEntityPicklist(this, City.alias);
        gridPanel.add(jCity);
	}

	public JCustomTextField getLabel() {
		return jLabel;
	}
	
	public JTextField getLabelFR() {
		return jLabelFR;
	}

	public JEntityPicklist getCity() {
		return jCity;
	}
	
	public void setLabel(String s) {
		jLabel.setText(s);
	}
	
	public void setLabelFR(String s) {
		jLabelFR.setText(s);
	}

	public void setCity(Integer id) {
		SwingUtils.selectValue(jCity, id);
	}
	
	public void clear() {
		jId.setText("");
		jLabel.setText("");
		jLabelFR.setText("");
		jCity.clear();
	}
	
	public void focus() {
		jLabel.focus();
	}

}
